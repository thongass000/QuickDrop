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
    private var isPlainTextTransfer = false
    
    public var wasRejected = false
    public var delegate: InboundNearbyConnectionDelegate?

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
            log("[InboundNearbyConnection] Received frame in state \(currentState)...")
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
                    log("[InboundNearbyConnection] Error deserializing secure message (probably due to packet filter)")
                    lastError = NearbyError.packetFilterError
                    protocolError()
                }
                
                if let smsg = smsg {
                    try decryptAndProcessReceivedSecureMessage(smsg)
                }
            }
        } catch {
            lastError = error
            log("[InboundNearbyConnection] Error receiving frame: \(error) in state \(currentState).")
            protocolError()
        }
    }
    

    override func processTransferSetupFrame(_ frame: Sharing_Nearby_Frame) throws {
        if frame.hasV1 && frame.v1.hasType, case .cancel = frame.v1.type {
            log("[InboundNearbyConnection] Transfer canceled")
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
            log("[InboundNearbyConnection] Unexpected connection state in processTransferSetupFrame: \(currentState)")
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
        
        if frame.payloadChunk.body.count > 0 {
            do {
                try fileInfo.fileHandle?.write(contentsOf: frame.payloadChunk.body)
                filesToBeReceived[id]!.bytesTransferred += Int64(frame.payloadChunk.body.count)
                fileInfo.progress?.completedUnitCount = filesToBeReceived[id]!.bytesTransferred
                
                // only for logging
                self.bytesTransferred += Int64(frame.payloadChunk.body.count)
            } catch {
                log("[InboundNearbyConnection] Error occurred during writing file: \(error.localizedDescription)")
                
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
                log("[InboundNearbyConnection] All files received, sending disconnection frame and disconnecting.")
                try sendDisconnectionAndDisconnect()
            }
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
                    
                    NearbyConnectionManager.shared.mainAppDelegate?.showCopiedToClipboardAlert()
                    
                    #elseif os(iOS)
                    // iOS clipboard
                    UIPasteboard.general.string = urlStr
                    
                    // Optionally show an alert (requires a way to present it)
                    // For example, post a notification or use a delegate to show a toast or alert
                    #endif
                } else if let url = URL(string: urlStr) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #elseif os(iOS)
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    #endif
                }
            }

            log("[InboundNearbyConnection] Received text payload. Disconnecting...")
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
            
            log("[InboundNearbyConnection] Received file payload. Disconnecting...")
            try sendDisconnectionAndDisconnect()
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
            log("[InboundNearbyConnection] Unsupported message type: \(msg.messageType)")
            throw NearbyError.ukey2
        }
        let clientInit: Securegcm_Ukey2ClientInit
        do {
            clientInit = try Securegcm_Ukey2ClientInit(serializedBytes: msg.messageData)
        } catch {
            sendUkey2Alert(type: .badMessageData)
            log("[InboundNearbyConnection] Failed to parse clientInit: \(error)")
            throw NearbyError.ukey2
        }
        guard clientInit.version == 1 else {
            sendUkey2Alert(type: .badVersion)
            log("[InboundNearbyConnection] Unsupported clientInit version: \(clientInit.version)")
            throw NearbyError.ukey2
        }
        guard clientInit.random.count == 32 else {
            sendUkey2Alert(type: .badRandom)
            log("[InboundNearbyConnection] Unsupported clientInit random: \(clientInit.random.count)")
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
            log("[InboundNearbyConnection] Unsupported clientInit handshakeCipher: \(clientInit.cipherCommitments)")
            throw NearbyError.ukey2
        }
        guard clientInit.nextProtocol == "AES_256_CBC-HMAC_SHA256" else {
            sendUkey2Alert(type: .badNextProtocol)
            log("[InboundNearbyConnection] Unsupported clientInit nextProtocol: \(clientInit.nextProtocol)")
            throw NearbyError.ukey2
        }

        let domain = Domain.instance(curve: .EC256r1)
        let (pubKey, privKey) = domain.makeKeyPair()
        publicKey = pubKey
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
            log("[InboundNearbyConnection] Unexpected message type \(msg.messageType)")
            throw NearbyError.ukey2
        }

        var sha = SHA512()
        sha.update(data: raw)
        guard cipherCommitment == Data(sha.finalize()) else {
            log("[InboundNearbyConnection] Invalid cipherCommitment in clientFinish")
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
            // Presumably used for all the phone number stuff that no one needs anyway
            pairedEncryption.v1.pairedKeyEncryption.secretIDHash = Data.randomData(length: 6)
            pairedEncryption.v1.pairedKeyEncryption.signedData = Data.randomData(length: 72)
            try sendTransferSetupFrame(pairedEncryption)
            currentState = .sentConnectionResponse
        } else {
            log("[InboundNearbyConnection] Unhandled offline frame plaintext: \(frame)")
        }
    }

    
    private func processPairedKeyEncryptionFrame(_ frame: Sharing_Nearby_Frame) throws {
        guard frame.hasV1, frame.v1.hasPairedKeyEncryption else { throw NearbyError.requiredFieldMissing("shareNearbyFrame.v1.pairedKeyEncryption") }
        var pairedResult = Sharing_Nearby_Frame()
        pairedResult.version = .v1
        pairedResult.v1 = Sharing_Nearby_V1Frame()
        pairedResult.v1.type = .pairedKeyResult
        pairedResult.v1.pairedKeyResult = Sharing_Nearby_PairedKeyResultFrame()
        pairedResult.v1.pairedKeyResult.status = .unable
        try sendTransferSetupFrame(pairedResult)
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
            }
            let metadata = TransferMetadata(files: filesToBeReceived.map { $0.value.meta }, id: id, pinCode: pinCode)
            DispatchQueue.main.async {
                self.delegate?.obtainUserConsent(for: metadata, from: self.remoteDeviceInfo!, connection: self)
            }
        }
        else if let textMetadata = frame.v1.introduction.textMetadata.first {
            
            if textMetadata.type == .url || textMetadata.type == .text {
                
                let isClipboardText = textMetadata.type == .text
                
                let metadata = TransferMetadata(files: [], id: id, pinCode: pinCode, textDescription: textMetadata.textTitle, transferType: isClipboardText ? .text : .url)
                textPayloadID = textMetadata.payloadID
                
                if isClipboardText{
                    isPlainTextTransfer = true
                }
                
                DispatchQueue.main.async {
                    self.delegate?.obtainUserConsent(for: metadata, from: self.remoteDeviceInfo!, connection: self)
                }
            }
            else {
                rejectDueToUnsupportedFileType(frame)
            }
        } else {
            rejectDueToUnsupportedFileType(frame)
        }
    }
    
    
    func rejectDueToUnsupportedFileType(_ frame: Sharing_Nearby_Frame) {
        
        log("[InboundNearbyConnection] Rejecting transfer due to unsupported file type. Frame is \(frame.debugDescription)")
        
        NearbyConnectionManager.shared.mainAppDelegate?.showUnsupportedFileAlert(for: remoteDeviceInfo)
        rejectTransfer(with: .unsupportedAttachmentType)
    }
    

    func submitUserConsent(accepted: Bool, storeInTemp: Bool = false) {
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
            log("[InboundNearbyConnection] Detected timeout, not accepting transfer")
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

            var frame = Sharing_Nearby_Frame()
            frame.version = .v1
            frame.v1.type = .response
            frame.v1.connectionResponse.status = .accept
            currentState = .receivingFiles
            try sendTransferSetupFrame(frame)
        } catch {
            lastError = error
            protocolError()
        }
    }

    
    private func rejectTransfer(with reason: Sharing_Nearby_ConnectionResponseFrame.Status = .reject) {
        
        self.wasRejected = true
        
        log("[InboundNearbyConnection] Rejecting transfer because of \( reason)")
        
        var frame = Sharing_Nearby_Frame()
        frame.version = .v1
        frame.v1.type = .response
        frame.v1.connectionResponse.status = reason
        do {
            try sendTransferSetupFrame(frame)
            try sendDisconnectionAndDisconnect()
        } catch {
            log("[InboundNearbyConnection] Error \(error)")
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
