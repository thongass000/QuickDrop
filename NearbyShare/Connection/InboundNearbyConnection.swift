//
//  InboundNearbyConnection.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

import CommonCrypto
import CryptoKit
import Foundation
import Network
import System
import BigInt
import SwiftECC

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class InboundNearbyConnection: NearbyConnection {
    
    private var filesToBeReceived: [Int64: InternalFileInfo] = [:]
    private var currentState: State = .initial
    private var cipherCommitment: Data?
    private var textPayloadID: Int64 = 0
    private var bytesToBeTransferred: Int64 = 0
    private var isAuthenticated = false
    private var peerCertificate: Sharing_Nearby_PublicCertificate? = nil
    var isPlainTextTransfer = false
    
    var wasUserRejected = false
    var delegate: InboundNearbyConnectionDelegate?

    enum State {
        case initial, receivedConnectionRequest, sentUkeyServerInit, receivedUkeyClientFinish, sentConnectionResponse, sentPairedKeyResult, receivedPairedKeyResult, waitingForUserConsent, receivingFiles, disconnected
    }
    

    override init(connection: NWConnection, id: String) {
        super.init(connection: connection, id: id)
    }
    

    override func disconnect() {
        super.disconnect()
        currentState = .disconnected
        deletePartiallyReceivedFiles()
  
        DispatchQueue.main.async {
            self.delegate?.connectionWasTerminated(connection: self, error: self.lastError)
            
            SaveFilesManager.shared.movePendingFilesToTarget()
            SaveFilesManager.shared.stopAccessingSecurityScopedResource()
        }
    }
    

    override func processReceivedFrame(frameData: Data) {
        
        if currentState != .receivingFiles {
            log("[InboundNearbyConnection \(self.id)] Received frame in state \(currentState)...")
        }
        
        do {
            switch currentState {
            case .initial:
                let frame = try Location_Nearby_Connections_OfflineFrame(serializedBytes: frameData)
                try processConnectionRequestFrame(frame)
            case .receivedConnectionRequest:
                let msg = try Securegcm_Ukey2Message(serializedBytes: frameData)
                ukeyClientInitMsgData = frameData
                try processUkey2ClientInit(msg)
            case .sentUkeyServerInit:
                let msg = try Securegcm_Ukey2Message(serializedBytes: frameData)
                try processUkey2ClientFinish(msg, raw: frameData)
            case .receivedUkeyClientFinish:
                let frame = try Location_Nearby_Connections_OfflineFrame(serializedBytes: frameData)
                try processConnectionResponseFrame(frame)
            default:

                var smsg: Securemessage_SecureMessage? = nil
                
                do {
                    smsg = try Securemessage_SecureMessage(serializedBytes: frameData)
                } catch {
                    log("[InboundNearbyConnection \(self.id)] Error deserializing secure message (probably due to packet filter)")
                    lastError = NearbyError.packetFilterError
                    protocolError()
                }
                
                if let smsg = smsg {
                    try decryptAndProcessReceivedSecureMessage(smsg)
                }
            }
        } catch {
            lastError = error
            log("[InboundNearbyConnection \(self.id)] Error receiving frame: \(error) in state \(currentState).")
            protocolError()
        }
    }
    

    override func processTransferSetupFrame(_ frame: Sharing_Nearby_Frame) throws {
        if frame.hasV1 && frame.v1.hasType, case .cancel = frame.v1.type {
            self.lastError = NearbyError.canceled(reason: .userCanceled)
            self.cancelled = true
            log("[InboundNearbyConnection \(self.id)] Transfer canceled")
            try sendDisconnectionAndDisconnect()
            return
        }
        switch currentState {
        case .sentConnectionResponse:
            try processPairedKeyEncryptionFrame(frame)
        case .sentPairedKeyResult:
            try processPairedKeyResultFrame(frame)
        case .receivedPairedKeyResult:
            try processIntroductionFrame(frame)
        default:
            if frame.hasV1, frame.v1.hasType, frame.v1.type == .progressUpdate {
                // ignore progress updates
                return
            }
            if frame.hasV1, frame.v1.hasType, frame.v1.type == .response, case .accept = frame.v1.connectionResponse.status {
                // ignore accept response frame, it is inferred since the other device set up the connection
                return
            }
            log("[InboundNearbyConnection \(self.id)] Unexpected connection state in processTransferSetupFrame: \(currentState)")
            log(frame.debugDescription)
        }
    }

    
    override func isServer() -> Bool {
        return true
    }
    

    override func processFileChunk(frame: Location_Nearby_Connections_PayloadTransferFrame) throws {
        
        let id = frame.payloadHeader.id
        
        guard let fileInfo = filesToBeReceived[id] else { throw NearbyError.protocolError("File payload ID \(id) is not known") }
        
        let currentOffset = fileInfo.bytesTransferred
        
        guard frame.payloadChunk.offset == currentOffset else { throw NearbyError.protocolError("Invalid offset into file \(frame.payloadChunk.offset), expected \(currentOffset)") }
        
        guard currentOffset + Int64(frame.payloadChunk.body.count) <= fileInfo.meta.size else { throw NearbyError.protocolError("Transferred file size exceeds previously specified value") }
        
        if !frame.payloadChunk.body.isEmpty {
            do {
                try fileInfo.fileHandle?.write(contentsOf: frame.payloadChunk.body)
                filesToBeReceived[id]!.bytesTransferred += Int64(frame.payloadChunk.body.count)
                fileInfo.progress?.completedUnitCount = filesToBeReceived[id]!.bytesTransferred
                
                self.bytesTransferred += Int64(frame.payloadChunk.body.count)
                NearbyConnectionManager.shared.updatedTransferProgress(connection: self, progress: Double(self.bytesTransferred) / Double(self.bytesToBeTransferred))
            } catch {
                log("[InboundNearbyConnection \(self.id)] Error occurred during writing file: \(error.localizedDescription)")
                
                throw NearbyError.protocolError(error.localizedDescription)
            }
        }
        else if (frame.payloadChunk.flags & 1) == 1 {
            try fileInfo.fileHandle?.close()
            filesToBeReceived[id]!.fileHandle = nil
            #if os(macOS)
            fileInfo.progress?.unpublish()
            #endif
            SaveFilesManager.shared.registerFileFinishedDownloading(fileInfo.destinationURL)

            filesToBeReceived.removeValue(forKey: id)
            
            if filesToBeReceived.isEmpty {
                log("[InboundNearbyConnection \(self.id)] All files received, sending disconnection frame and disconnecting.")
                NearbyConnectionManager.shared.updatedTransferProgress(connection: self, progress: 1)
                try sendDisconnectionAndDisconnect()
            }
        }
        else {
            log("[InboundNearbyConnection \(self.id)] Received file chunk with no body and no flags, ignoring it.")
        }
    }

    
    override func processBytesPayload(payload: Data, id: Int64) throws -> Bool {
        if id == textPayloadID {
            if let urlStr = String(data: payload, encoding: .utf8) {
                
                if isPlainTextTransfer {
                    #if os(macOS)
                    // macOS clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(urlStr, forType: .string)
                    #elseif os(iOS)
                    // iOS clipboard
                    UIPasteboard.general.string = urlStr
                    #endif
                } else if let url = URL(string: urlStr) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #elseif os(iOS) && !EXTENSION
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    #endif
                }
            }

            log("[InboundNearbyConnection \(self.id)] Received text payload. Disconnecting...")
            try sendDisconnectionAndDisconnect()
            return true
        }
        else if let fileInfo = filesToBeReceived[id] {
            fileInfo.fileHandle?.write(payload)
            filesToBeReceived[id]!.bytesTransferred += Int64(payload.count)
            fileInfo.progress?.completedUnitCount = filesToBeReceived[id]!.bytesTransferred
            try fileInfo.fileHandle?.close()
            filesToBeReceived[id]!.fileHandle = nil
            #if os(macOS)
            fileInfo.progress?.unpublish()
            #endif
            filesToBeReceived.removeValue(forKey: id)
            SaveFilesManager.shared.registerFileFinishedDownloading(fileInfo.destinationURL)
            
            if filesToBeReceived.isEmpty {
                log("[InboundNearbyConnection \(self.id)] Received file payload. Disconnecting...")
                NearbyConnectionManager.shared.updatedTransferProgress(connection: self, progress: 1)
                try sendDisconnectionAndDisconnect()
            }
            return true
        }
        return false
    }
    

    private func processConnectionRequestFrame(_ frame: Location_Nearby_Connections_OfflineFrame) throws {
        
        guard frame.hasV1 && frame.v1.hasConnectionRequest && frame.v1.connectionRequest.hasEndpointInfo else { throw NearbyError.requiredFieldMissing("connectionRequest.endpointInfo") }
        
        guard case .connectionRequest = frame.v1.type else { throw NearbyError.protocolError("Unexpected frame type \(frame.v1.type)") }
        
        let endpointInfo = frame.v1.connectionRequest.endpointInfo
        
        guard endpointInfo.count > 17 else { throw NearbyError.protocolError("Endpoint info too short") }
        
        let deviceNameLength = Int(endpointInfo[17])
        
        guard endpointInfo.count >= deviceNameLength + 18 else { throw NearbyError.protocolError("Endpoint info too short to contain the device name") }
        
        guard let deviceName = String(data: endpointInfo[18 ..< (18 + deviceNameLength)], encoding: .utf8) else { throw NearbyError.protocolError("Device name is not valid UTF-8") }
        
        let rawDeviceType = Int(endpointInfo[0] & 7) >> 1
        
        remoteDeviceInfo = RemoteDeviceInfo(name: deviceName, type: RemoteDeviceInfo.DeviceType.fromRawValue(value: rawDeviceType))
        currentState = .receivedConnectionRequest
    }
    

    private func processUkey2ClientInit(_ msg: Securegcm_Ukey2Message) throws {
        guard msg.hasMessageType, msg.hasMessageData else { throw NearbyError.requiredFieldMissing("clientInit ukey2message.type|data") }
        guard case .clientInit = msg.messageType else {
            sendUkey2Alert(type: .badMessageType)
            log("[InboundNearbyConnection \(self.id)] Unsupported message type: \(msg.messageType)")
            throw NearbyError.ukey2
        }
        let clientInit: Securegcm_Ukey2ClientInit
        do {
            clientInit = try Securegcm_Ukey2ClientInit(serializedBytes: msg.messageData)
        } catch {
            sendUkey2Alert(type: .badMessageData)
            log("[InboundNearbyConnection \(self.id)] Failed to parse clientInit: \(error)")
            throw NearbyError.ukey2
        }
        guard clientInit.version == 1 else {
            sendUkey2Alert(type: .badVersion)
            log("[InboundNearbyConnection \(self.id)] Unsupported clientInit version: \(clientInit.version)")
            throw NearbyError.ukey2
        }
        guard clientInit.random.count == 32 else {
            sendUkey2Alert(type: .badRandom)
            log("[InboundNearbyConnection \(self.id)] Unsupported clientInit random: \(clientInit.random.count)")
            throw NearbyError.ukey2
        }
        var found = false
        for commitment in clientInit.cipherCommitments {
            if case .p256Sha512 = commitment.handshakeCipher {
                found = true
                cipherCommitment = commitment.commitment
                break
            }
        }
        guard found else {
            sendUkey2Alert(type: .badHandshakeCipher)
            log("[InboundNearbyConnection \(self.id)] Unsupported clientInit handshakeCipher: \(clientInit.cipherCommitments)")
            throw NearbyError.ukey2
        }
        guard clientInit.nextProtocol == "AES_256_CBC-HMAC_SHA256" else {
            sendUkey2Alert(type: .badNextProtocol)
            log("[InboundNearbyConnection \(self.id)] Unsupported clientInit nextProtocol: \(clientInit.nextProtocol)")
            throw NearbyError.ukey2
        }

        let domain = Domain.instance(curve: .EC256r1)
        let (pubKey, privKey) = domain.makeKeyPair()
        privateKey = privKey

        var serverInit = Securegcm_Ukey2ServerInit()
        serverInit.version = 1
        serverInit.random = Data.randomData(length: 32)
        serverInit.handshakeCipher = .p256Sha512

        var pkey = Securemessage_GenericPublicKey()
        pkey.type = .ecP256
        pkey.ecP256PublicKey = Securemessage_EcP256PublicKey()
        pkey.ecP256PublicKey.x = Data(pubKey.w.x.asSignedBytes())
        pkey.ecP256PublicKey.y = Data(pubKey.w.y.asSignedBytes())
        serverInit.publicKey = try pkey.serializedData()

        var serverInitMsg = Securegcm_Ukey2Message()
        serverInitMsg.messageType = .serverInit
        serverInitMsg.messageData = try serverInit.serializedData()
        let serverInitData = try serverInitMsg.serializedData()
        ukeyServerInitMsgData = serverInitData
        sendFrameAsync(serverInitData)
        currentState = .sentUkeyServerInit
    }

    
    private func processUkey2ClientFinish(_ msg: Securegcm_Ukey2Message, raw: Data) throws {
        guard msg.hasMessageType, msg.hasMessageData else { throw NearbyError.requiredFieldMissing("clientFinish ukey2message.type|data") }
        guard case .clientFinish = msg.messageType else {
            log("[InboundNearbyConnection \(self.id)] Unexpected message type \(msg.messageType)")
            throw NearbyError.ukey2
        }

        var sha = SHA512()
        sha.update(data: raw)
        guard cipherCommitment == Data(sha.finalize()) else {
            log("[InboundNearbyConnection \(self.id)] Invalid cipherCommitment in clientFinish")
            throw NearbyError.ukey2
        }

        let clientFinish = try Securegcm_Ukey2ClientFinished(serializedBytes: msg.messageData)
        guard clientFinish.hasPublicKey else { throw NearbyError.requiredFieldMissing("ukey2clientFinish.publicKey") }
        let clientKey = try Securemessage_GenericPublicKey(serializedBytes: clientFinish.publicKey)

        try finalizeKeyExchange(peerKey: clientKey)

        currentState = .receivedUkeyClientFinish
    }
    

    private func processConnectionResponseFrame(_ frame: Location_Nearby_Connections_OfflineFrame) throws {
        guard frame.hasV1, frame.v1.hasType else { throw NearbyError.requiredFieldMissing("offlineFrame.v1.type") }
        if case .connectionResponse = frame.v1.type {
            var resp = Location_Nearby_Connections_OfflineFrame()
            resp.version = .v1
            resp.v1 = Location_Nearby_Connections_V1Frame()
            resp.v1.type = .connectionResponse
            resp.v1.connectionResponse = Location_Nearby_Connections_ConnectionResponseFrame()
            resp.v1.connectionResponse.response = .accept
            resp.v1.connectionResponse.status = 0
            resp.v1.connectionResponse.osInfo = Location_Nearby_Connections_OsInfo()
            resp.v1.connectionResponse.osInfo.type = .apple
            try sendFrameAsync(resp.serializedData())

            encryptionDone = true

            var pairedEncryption = Sharing_Nearby_Frame()
            pairedEncryption.version = .v1
            pairedEncryption.v1 = Sharing_Nearby_V1Frame()
            pairedEncryption.v1.type = .pairedKeyEncryption
            pairedEncryption.v1.pairedKeyEncryption = Sharing_Nearby_PairedKeyEncryptionFrame()
            
            // For inbound connections, we do not use provide secretIDHash and signedData
            pairedEncryption.v1.pairedKeyEncryption.secretIDHash = Data.randomData(length: 6)
            pairedEncryption.v1.pairedKeyEncryption.signedData = Data.randomData(length: 72)
            
            try sendTransferSetupFrame(pairedEncryption)
            currentState = .sentConnectionResponse
        } else {
            log("[InboundNearbyConnection \(self.id)] Unhandled offline frame plaintext: \(frame)")
        }
    }


    private func processPairedKeyEncryptionFrame(_ frame: Sharing_Nearby_Frame) throws {
        
        guard frame.hasV1, frame.v1.hasPairedKeyEncryption else { throw NearbyError.requiredFieldMissing("shareNearbyFrame.v1.pairedKeyEncryption") }
        
        let pkeFrame = frame.v1.pairedKeyEncryption
        
        if pkeFrame.secretIDHash.isEmpty {
            log("[InboundNearbyConnection \(self.id)] Detected legacy peer.")
        }
        else {
            log("[InboundNearbyConnection \(self.id)] Detected QuickDrop peer.")
        }
        
        // Check if we can accept the connection automatically
        if !pkeFrame.secretIDHash.isEmpty,
            let trustedCertData = TrustStore.shared.findTrustedKey(for: pkeFrame.secretIDHash),
            let trustedCert = try? Sharing_Nearby_PublicCertificate(serializedBytes: trustedCertData),
            let peerGenericKey = try? Securemessage_GenericPublicKey(serializedBytes: trustedCert.publicKey),
            let authKeyData = self.authKey?.data() {
            
            log("[InboundNearbyConnection \(self.id)] Found trusted certificate for secretIDHash: \(pkeFrame.secretIDHash.hex)")

            let domain = Domain.instance(curve: .EC256r1)
            let ecKey = peerGenericKey.ecP256PublicKey
            let point = Point(BInt(magnitude: [UInt8](ecKey.x)), BInt(magnitude: [UInt8](ecKey.y)))
            
            guard let peerPublicKey = try? ECPublicKey(domain: domain, w: point) else {
                log("[InboundNearbyConnection \(self.id)] Paired key auth failed: Invalid peer public key.")
                try automaticAuthFailed()
                return
            }

            do {
                let signature =  try ECSignature(asn1: .build(pkeFrame.signedData), domain: domain)
                
                if peerPublicKey.verify(signature: signature, msg: authKeyData) {
                    log("[InboundNearbyConnection \(self.id)] Paired key authentication successful.")
                    try sendPairedKeyResult(status: .success)
                    isAuthenticated = true
                } else {
                    log("[InboundNearbyConnection \(self.id)] Paired key auth failed: Signature verification failed.")
                    try automaticAuthFailed()
                }
            }
            catch {
                log("[InboundNearbyConnection \(self.id)] Paired key auth failed: Invalid signature length.")
                try automaticAuthFailed()
                return
            }

        } else {
            try automaticAuthFailed()
        }
        
        func automaticAuthFailed() throws {
            // Store certificate of peer to let user device later to trust it
            if let peerCertificate = frame.v1.certificateInfo.publicCertificate.first {
                log("[InboundNearbyConnection \(self.id)] Storing peer certificate for potential later use")
                self.peerCertificate = peerCertificate
            }
            
            try sendPairedKeyResult(status: .unable)
        }
    }
    

    private func sendPairedKeyResult(status: Sharing_Nearby_PairedKeyResultFrame.Status) throws {
        var resultFrame = Sharing_Nearby_Frame()
        resultFrame.version = .v1
        resultFrame.v1.type = .pairedKeyResult
        resultFrame.v1.pairedKeyResult.status = status
        try sendTransferSetupFrame(resultFrame)
        currentState = .sentPairedKeyResult
    }

    
    private func processPairedKeyResultFrame(_ frame: Sharing_Nearby_Frame) throws {
        guard frame.hasV1, frame.v1.hasPairedKeyResult else { throw NearbyError.requiredFieldMissing("shareNearbyFrame.v1.pairedKeyResult") }
        currentState = .receivedPairedKeyResult
    }
    

    private func makeFileDestinationURL(_ initialDest: URL) -> URL {
        var dest = initialDest
        if FileManager.default.fileExists(atPath: dest.path) {
            var counter = 1
            var path: String
            let ext = dest.pathExtension
            let baseUrl = dest.deletingPathExtension()
            repeat {
                path = "\(baseUrl.path) (\(counter))"
                if !ext.isEmpty {
                    path += ".\(ext)"
                }
                counter += 1
            } while FileManager.default.fileExists(atPath: path)
            dest = URL(fileURLWithPath: path)
        }
        return dest
    }
    

    private func processIntroductionFrame(_ frame: Sharing_Nearby_Frame) throws {
        guard frame.hasV1, frame.v1.hasIntroduction else { throw NearbyError.requiredFieldMissing("shareNearbyFrame.v1.introduction") }
        currentState = .waitingForUserConsent

        if frame.v1.introduction.fileMetadata.count > 0 && frame.v1.introduction.textMetadata.isEmpty {
            let saveDirectory = SaveFilesManager.shared.getSaveDirectory()

            for file in frame.v1.introduction.fileMetadata {
                let dest = makeFileDestinationURL(saveDirectory.appendingPathComponent(file.name))
                let info = InternalFileInfo(meta: FileMetadata(name: file.name, size: file.size, mimeType: file.mimeType),
                                            payloadID: file.payloadID,
                                            destinationURL: dest)
                filesToBeReceived[file.payloadID] = info
                bytesToBeTransferred += file.size
            }
            let metadata = TransferMetadata(files: filesToBeReceived.map { $0.value.meta }, id: id, pinCode: pinCode, allowsToBeAddedAsTrustedDevice: self.peerCertificate != nil)
            checkIfCanProceed(metadata: metadata)
        }
        else if let textMetadata = frame.v1.introduction.textMetadata.first {
            
            if textMetadata.type == .url || textMetadata.type == .text {
                
                let isClipboardText = textMetadata.type == .text
                
                let metadata = TransferMetadata(files: [], id: id, pinCode: pinCode, textDescription: textMetadata.textTitle, transferType: isClipboardText ? .text : .url, allowsToBeAddedAsTrustedDevice: self.peerCertificate != nil)
                textPayloadID = textMetadata.payloadID
                
                if isClipboardText {
                    isPlainTextTransfer = true
                }
                
                checkIfCanProceed(metadata: metadata)
            }
            else {
                rejectDueToUnsupportedFileType(frame)
            }
        } else {
            rejectDueToUnsupportedFileType(frame)
        }
        
        
        func checkIfCanProceed(metadata: TransferMetadata) {
            
            let acceptAutomatically = isAuthenticated || Settings.shared.automaticallyAcceptFiles
            
            DispatchQueue.main.async {
                self.delegate?.obtainUserConsent(transfer: metadata, device: self.remoteDeviceInfo!, connection: self, acceptAutomatically: acceptAutomatically)
            }
        }
    }
    
    
    func rejectDueToUnsupportedFileType(_ frame: Sharing_Nearby_Frame) {
        
        log("[InboundNearbyConnection \(self.id)] Rejecting transfer due to unsupported file type. Frame is \(frame.debugDescription)")
        
        lastError = NearbyError.canceled(reason: .unsupportedType)
        rejectTransfer(with: .unsupportedAttachmentType)
    }
    

    func submitUserConsent(accepted: Bool, trustDevice: Bool, storeInTemp: Bool = false) {
        if trustDevice, let peerCertificate = peerCertificate, let remoteDeviceInfo = remoteDeviceInfo {
            TrustStore.shared.addTrusted(certificate: peerCertificate, device: remoteDeviceInfo)
        }
        
        DispatchQueue.global(qos: .utility).async {
            if accepted {
                self.acceptTransfer(storeInTemp: storeInTemp)
            } else {
                self.rejectTransfer()
            }
        }
    }

    
    private func acceptTransfer(storeInTemp: Bool) {
        if currentState == .disconnected {
            log("[InboundNearbyConnection \(self.id)] Detected timeout, not accepting transfer")
            return
        }

        do {
            if storeInTemp {
                try FileManager.default.createDirectory(at: SaveFilesManager.shared.tempDirectory, withIntermediateDirectories: true)
            }

            for (id, file) in filesToBeReceived {
                let targetURL = storeInTemp ? SaveFilesManager.shared.tempDirectory.appendingPathComponent(file.destinationURL.lastPathComponent) : file.destinationURL

                FileManager.default.createFile(atPath: targetURL.path, contents: nil)
                let handle = try FileHandle(forWritingTo: targetURL)
                filesToBeReceived[id]!.fileHandle = handle

                let progress = Progress()
                progress.fileURL = targetURL
                progress.totalUnitCount = file.meta.size
                progress.kind = .file
                progress.isPausable = false
                #if os(macOS)
                progress.publish()
                #endif
                filesToBeReceived[id]!.progress = progress
                filesToBeReceived[id]!.created = true
            }
            
            let totalBytes = filesToBeReceived.values.reduce(0) { $0 + $1.meta.size }
            let gigabytes = Double(totalBytes) / 1_000_000_000
            log("[InboundNearbyConnection \(self.id)] Accepted \(filesToBeReceived.count) file(s) with size \(totalBytes) bytes (\(gigabytes) GB)")

            var frame = Sharing_Nearby_Frame()
            frame.version = .v1
            frame.v1.type = .response
            frame.v1.connectionResponse.status = .accept
            currentState = .receivingFiles
            isTransferring = true
            try sendTransferSetupFrame(frame)
        } catch {
            lastError = error
            protocolError()
        }
    }

    
    private func rejectTransfer(with reason: Sharing_Nearby_ConnectionResponseFrame.Status = .reject) {
        
        // rejected by user
        if reason == .reject {
            self.wasUserRejected = true
        }
        
        log("[InboundNearbyConnection \(self.id)] Rejecting transfer because of \( reason)")
        
        var frame = Sharing_Nearby_Frame()
        frame.version = .v1
        frame.v1.type = .response
        frame.v1.connectionResponse.status = reason
        do {
            try sendTransferSetupFrame(frame)
            try sendDisconnectionAndDisconnect()
        } catch {
            log("[InboundNearbyConnection \(self.id)] Error \(error)")
            protocolError()
        }
    }
    
    
    private func deletePartiallyReceivedFiles() {
        for (_, file) in filesToBeReceived {
            
            #if os(macOS)
            if let progress = file.progress {
                progress.unpublish()
            }
            #endif
            
            guard file.created else { continue }
            do {
                try FileManager.default.removeItem(at: file.destinationURL)
            }
            catch {
                // if it fails, we don't care. Could be because file was not created yet
            }
        }
    }
}
