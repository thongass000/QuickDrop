//
//  InboundNearbyConnection.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

import AppKit
import CommonCrypto
import CryptoKit
import Foundation
import Network
import System

import BigInt
import SwiftECC

class InboundNearbyConnection: NearbyConnection {
    private var currentState: State = .initial
    public var delegate: InboundNearbyConnectionDelegate?
    private var cipherCommitment: Data?

    private var textPayloadID: Int64 = 0

    enum State {
        case initial, receivedConnectionRequest, sentUkeyServerInit, receivedUkeyClientFinish, sentConnectionResponse, sentPairedKeyResult, receivedPairedKeyResult, waitingForUserConsent, receivingFiles, disconnected
    }

    override init(connection: NWConnection, id: String) {
        super.init(connection: connection, id: id)
    }

    override func handleConnectionClosure() {
        super.handleConnectionClosure()
        currentState = .disconnected
        do {
            try deletePartiallyReceivedFiles()
        } catch {
            log("Error deleting partially received files: \(error)")
        }
        DispatchQueue.main.async {
            self.delegate?.connectionWasTerminated(connection: self, error: self.lastError)

            SaveFilesManager.shared.movePendingFilesToTarget()
            SaveFilesManager.shared.stopAccessingSecurityScopedResource()
        }
    }

    override func processReceivedFrame(frameData: Data) {
        if currentState != .receivingFiles {
            log("Received frame in state \(currentState)...")
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
                var smsg: Securemessage_SecureMessage

                do {
                    smsg = try Securemessage_SecureMessage(serializedBytes: frameData)
                } catch {
                    log("Error deserializing secure message. Trying again....")

                    // last 32 bytes = HMAC key
                    // change 2 bytes before to 0x12 0x20 for Protobuf to succeed

                    if frameData.count < 34 {
                        throw NearbyError.protocolError("Frame too short")
                    }

                    var newData = frameData
                    let count = newData.count
                    newData[count - 34] = 0x12
                    newData[count - 33] = 0x20

                    smsg = try Securemessage_SecureMessage(serializedBytes: newData)

                    log("Secure message deserialized successfully after fixing Protobuf message")
                }
                try decryptAndProcessReceivedSecureMessage(smsg)
            }
        } catch {
            lastError = error
            log("Deserialization error: \(error) in state \(currentState). Payload: \(frameData.hex)")

            // log("Public Key: \(publicKey?.pem ?? "nil")")
            // log("Private Key: \(privateKey?.pem ?? "nil")")
            // log("Ukey Client Init Msg: \(ukeyClientInitMsgData?.hex ?? "nil")")
            // log("Ukey Server Init Msg: \(ukeyServerInitMsgData?.hex ?? "nil")")
            log("S1: \(decryptKey?.map { String(format: "%02x", $0) }.joined() ?? "nil")")
            // log("Encrypt Key: \(encryptKey?.map { String(format: "%02x", $0) }.joined() ?? "nil")")
            log("Received HMAC/Signature Key: \(recvHmacKey?.withUnsafeBytes { Data(Array($0)) }.map { String(format: "%02x", $0) }.joined() ?? "nil")")
            log("Sent HMAC/Signature Key: \(sendHmacKey?.withUnsafeBytes { Data(Array($0)) }.map { String(format: "%02x", $0) }.joined() ?? "nil")")

            protocolError()
        }
    }

    override func processTransferSetupFrame(_ frame: Sharing_Nearby_Frame) throws {
        if frame.hasV1 && frame.v1.hasType, case .cancel = frame.v1.type {
            log("Transfer canceled")
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
            log("Unexpected connection state in processTransferSetupFrame: \(currentState)")
            log(frame.debugDescription)
        }
    }

    override func isServer() -> Bool {
        return true
    }

    override func processFileChunk(frame: Location_Nearby_Connections_PayloadTransferFrame) throws {
        let id = frame.payloadHeader.id
        guard let fileInfo = transferredFiles[id] else { throw NearbyError.protocolError("File payload ID \(id) is not known") }
        let currentOffset = fileInfo.bytesTransferred
        guard frame.payloadChunk.offset == currentOffset else { throw NearbyError.protocolError("Invalid offset into file \(frame.payloadChunk.offset), expected \(currentOffset)") }
        guard currentOffset + Int64(frame.payloadChunk.body.count) <= fileInfo.meta.size else { throw NearbyError.protocolError("Transferred file size exceeds previously specified value") }
        if frame.payloadChunk.body.count > 0 {
            fileInfo.fileHandle?.write(frame.payloadChunk.body)
            transferredFiles[id]!.bytesTransferred += Int64(frame.payloadChunk.body.count)
            fileInfo.progress?.completedUnitCount = transferredFiles[id]!.bytesTransferred
        } else if (frame.payloadChunk.flags & 1) == 1 {
            try fileInfo.fileHandle?.close()
            transferredFiles[id]!.fileHandle = nil
            fileInfo.progress?.unpublish()
            SaveFilesManager.shared.registerFileFinishedDownloading(fileInfo.destinationURL)

            transferredFiles.removeValue(forKey: id)
            if transferredFiles.isEmpty {
                try sendDisconnectionAndDisconnect()
            }
        }
    }

    override func processBytesPayload(payload: Data, id: Int64) throws -> Bool {
        if id == textPayloadID {
            if let urlStr = String(data: payload, encoding: .utf8), let url = URL(string: urlStr) {
                NSWorkspace.shared.open(url)
            }
            try sendDisconnectionAndDisconnect()
            return true
        } else if let fileInfo = transferredFiles[id] {
            fileInfo.fileHandle?.write(payload)
            transferredFiles[id]!.bytesTransferred += Int64(payload.count)
            fileInfo.progress?.completedUnitCount = transferredFiles[id]!.bytesTransferred
            try fileInfo.fileHandle?.close()
            transferredFiles[id]!.fileHandle = nil
            fileInfo.progress?.unpublish()
            transferredFiles.removeValue(forKey: id)
            SaveFilesManager.shared.registerFileFinishedDownloading(fileInfo.destinationURL)
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
            throw NearbyError.ukey2
        }
        let clientInit: Securegcm_Ukey2ClientInit
        do {
            clientInit = try Securegcm_Ukey2ClientInit(serializedBytes: msg.messageData)
        } catch {
            sendUkey2Alert(type: .badMessageData)
            throw NearbyError.ukey2
        }
        guard clientInit.version == 1 else {
            sendUkey2Alert(type: .badVersion)
            throw NearbyError.ukey2
        }
        guard clientInit.random.count == 32 else {
            sendUkey2Alert(type: .badRandom)
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
            throw NearbyError.ukey2
        }
        guard clientInit.nextProtocol == "AES_256_CBC-HMAC_SHA256" else {
            sendUkey2Alert(type: .badNextProtocol)
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
        guard case .clientFinish = msg.messageType else { throw NearbyError.ukey2 }

        var sha = SHA512()
        sha.update(data: raw)
        guard cipherCommitment == Data(sha.finalize()) else { throw NearbyError.ukey2 }

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
            log("Unhandled offline frame plaintext: \(frame)")
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
                transferredFiles[file.payloadID] = info
            }
            let metadata = TransferMetadata(files: transferredFiles.map { $0.value.meta }, id: id, pinCode: pinCode)
            DispatchQueue.main.async {
                self.delegate?.obtainUserConsent(for: metadata, from: self.remoteDeviceInfo!, connection: self)
            }
        } else if frame.v1.introduction.textMetadata.count == 1 {
            let meta = frame.v1.introduction.textMetadata[0]
            if case .url = meta.type {
                let metadata = TransferMetadata(files: [], id: id, pinCode: pinCode, textDescription: meta.textTitle)
                textPayloadID = meta.payloadID
                DispatchQueue.main.async {
                    self.delegate?.obtainUserConsent(for: metadata, from: self.remoteDeviceInfo!, connection: self)
                }
            } else if case .text = meta.type {
                let saveDirectory = SaveFilesManager.shared.getSaveDirectory()

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                let dest = makeFileDestinationURL(saveDirectory.appendingPathComponent("\(dateFormatter.string(from: Date())).txt"))
                let info = InternalFileInfo(meta: FileMetadata(name: dest.lastPathComponent, size: meta.size, mimeType: "text/plain"),
                                            payloadID: meta.payloadID,
                                            destinationURL: dest)
                transferredFiles[meta.payloadID] = info
                DispatchQueue.main.async {
                    self.delegate?.obtainUserConsent(for: TransferMetadata(files: [info.meta], id: self.id, pinCode: self.pinCode), from: self.remoteDeviceInfo!, connection: self)
                }
            } else {
                rejectTransfer(with: .unsupportedAttachmentType)
            }
        } else {
            rejectTransfer(with: .unsupportedAttachmentType)
        }
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
            log("Detected timeout, not accepting transfer")
            return
        }

        do {
            if storeInTemp {
                try FileManager.default.createDirectory(at: SaveFilesManager.shared.tempDirectory, withIntermediateDirectories: true)
            }

            for (id, file) in transferredFiles {
                let targetURL = storeInTemp ? SaveFilesManager.shared.tempDirectory.appendingPathComponent(file.destinationURL.lastPathComponent) : file.destinationURL

                FileManager.default.createFile(atPath: targetURL.path, contents: nil)
                let handle = try FileHandle(forWritingTo: targetURL)
                transferredFiles[id]!.fileHandle = handle

                let progress = Progress()
                progress.fileURL = targetURL
                progress.totalUnitCount = file.meta.size
                progress.kind = .file
                progress.isPausable = false
                progress.publish()
                transferredFiles[id]!.progress = progress
                transferredFiles[id]!.created = true
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
        var frame = Sharing_Nearby_Frame()
        frame.version = .v1
        frame.v1.type = .response
        frame.v1.connectionResponse.status = reason
        do {
            try sendTransferSetupFrame(frame)
            try sendDisconnectionAndDisconnect()
        } catch {
            log("Error \(error)")
            protocolError()
        }
    }

    private func deletePartiallyReceivedFiles() throws {
        for (_, file) in transferredFiles {
            guard file.created else { continue }
            try FileManager.default.removeItem(at: file.destinationURL)
        }
    }
}

protocol InboundNearbyConnectionDelegate {
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo, connection: InboundNearbyConnection)
    func connectionWasTerminated(connection: InboundNearbyConnection, error: Error?)
}

public class SaveFilesManager {
    private init() {}

    public static let shared = SaveFilesManager()

    let tempDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Pending")
    private var securityScopeUrl: URL?

    private var filesFinishedDownloading = [URL]()

    public func registerFileFinishedDownloading(_ fileURL: URL) {
        filesFinishedDownloading.append(fileURL)
    }

    public func movePendingFilesToTarget() {
        if !isPlusVersion() {
            return
        }

        log("Moving pending files to target directory")

        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)

            let target = getSaveDirectory()

            for file in files {
                let fileName = file.lastPathComponent
                let destinationURL = target.appendingPathComponent(fileName)

                if !filesFinishedDownloading.contains(destinationURL) {
                    log("File \(file) not finished downloading, skipping")
                    continue
                }

                log("Moving file: \(file.lastPathComponent) to \(destinationURL.lastPathComponent)")
                try fileManager.copyItem(at: file, to: destinationURL)

                let progress = Progress()
                progress.fileURL = destinationURL
                progress.totalUnitCount = 10
                progress.kind = .file
                progress.isPausable = false
                progress.publish()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    progress.completedUnitCount = 10
                    progress.unpublish()
                }

                try fileManager.removeItem(at: file)
            }

            stopAccessingSecurityScopedResource()

            log("Moved all pending files to target directory")

        } catch {
            log("Error moving pending files: \(error)")
        }
    }

    public func stopAccessingSecurityScopedResource() {
        guard let url = securityScopeUrl else {
            return
        }

        log("Stopping access to security scoped resource: \(url)")
        url.stopAccessingSecurityScopedResource()
        securityScopeUrl = nil
    }

    public func getSaveDirectory() -> URL {
        if let securityScopeUrl = securityScopeUrl {
            log("Using existing security scope URL: \(securityScopeUrl)")
            return securityScopeUrl
        }

        if let bookmarkData = UserDefaults.standard.data(forKey: UserDefaultsKeys.saveFolderBookmark.rawValue) {
            var isStale = false

            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                if !isStale {
                    if url.startAccessingSecurityScopedResource() {
                        log("Successfully accessed security scoped resource: \(url)")

                        securityScopeUrl = url
                        return url
                    }
                } else {
                    print("Bookmark is stale, using default downloads folder.")
                }

            } catch {
                print("Failed to resolve bookmark: \(error), using default downloads folder.")
            }
        }

        do {
            return try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true).resolvingSymlinksInPath()
        } catch {
            fatalError("Failed to get downloads directory: \(error)")
        }
    }
}

extension Data {
    var hex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    var dataFromHex: Data {
        var data = Data(capacity: count / 2)
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2)
            if nextIndex <= endIndex,
               let byte = UInt8(self[index ..< nextIndex], radix: 16)
            {
                data.append(byte)
            } else {
                break // or handle invalid hex gracefully
            }
            index = nextIndex
        }
        return data
    }
}
