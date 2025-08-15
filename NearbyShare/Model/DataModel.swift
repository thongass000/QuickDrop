//
//  DataModel.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.07.25.
//

import Foundation
import Network
import CryptoKit
import SwiftECC


protocol InboundNearbyConnectionDelegate {
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo, connection: InboundNearbyConnection)
    func connectionWasTerminated(connection: InboundNearbyConnection, error: Error?)
}


protocol OutboundNearbyConnectionDelegate {
    func outboundConnectionWasEstablished(connection: OutboundNearbyConnection)
    func outboundConnection(connection: OutboundNearbyConnection, transferProgress: Double)
    func outboundConnectionTransferAccepted(connection: OutboundNearbyConnection)
    func outboundConnection(connection: OutboundNearbyConnection, failedWithError: Error)
    func outboundConnectionTransferFinished(connection: OutboundNearbyConnection)
}


public protocol MainAppDelegate {
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo)
    func incomingTransfer(id: String, didFinishWith error: Error?)
    func showCopiedToClipboardAlert()
    func showUnsupportedFileAlert(for: RemoteDeviceInfo?)
}


public protocol ShareExtensionDelegate: AnyObject {
    func addDevice(device: RemoteDeviceInfo)
    func removeDevice(id: String)
    func startTransferWithQrCode(device: RemoteDeviceInfo)
    func connectionWasEstablished(pinCode: String)
    func connectionFailed(with error: Error)
    func transferAccepted()
    func transferProgress(progress: Double)
    func transferFinished()
}


public struct RemoteDeviceInfo: Identifiable, Equatable {
    public let name: String?
    public let type: DeviceType
    public let qrCodeData:Data?
    public var id: String?

    init(name: String, type: DeviceType, id: String? = nil) {
        self.name = name
        self.type = type
        self.id = id
        self.qrCodeData = nil
    }

    init(info: EndpointInfo, id: String? = nil) {
        self.name = info.name
        self.type = info.deviceType
        self.qrCodeData = info.qrCodeData
        self.id = id
    }

    
    public enum DeviceType: Int32 {
        case unknown = 0
        case phone
        case tablet
        case computer

        public static func fromRawValue(value: Int) -> DeviceType {
            switch value {
            case 0:
                return .unknown
            case 1:
                return .phone
            case 2:
                return .tablet
            case 3:
                return .computer
            default:
                return .unknown
            }
        }
    }
    
    
    public var icon: String {
        switch type {
            case .computer:
                return "laptopcomputer"
            default:
                return "smartphone"
        }
    }
}


public struct TransferMetadata {
    public let files: [FileMetadata]
    public let id: String
    public let pinCode: String?
    public let textDescription: String?
    public let type: TransferType

    init(files: [FileMetadata], id: String, pinCode: String?, textDescription: String? = nil, transferType: TransferType = .file) {
        self.files = files
        self.id = id
        self.pinCode = pinCode
        self.textDescription = textDescription
        self.type = transferType
    }
    
    public enum TransferType {
        case file
        case text
        case url
    }
}


public struct FileMetadata {
    public let name: String
    public let size: Int64
    public let mimeType: String
}


struct EndpointInfo {
    var name: String?
    let deviceType: RemoteDeviceInfo.DeviceType
    let qrCodeData: Data?

    
    init(name: String, deviceType: RemoteDeviceInfo.DeviceType) {
        self.name = name
        self.deviceType = deviceType
        self.qrCodeData = nil
    }

    
    init?(data: Data) {
        guard data.count > 17 else { return nil }
        
        let hasName = (data[0] & 0x10) == 0
        let deviceNameLength: Int
        let deviceName: String?
        
        if hasName {
            deviceNameLength = Int(data[17])
            guard data.count >= deviceNameLength + 18 else { return nil }
            guard let newDeviceName = String(data: data[18..<(18 + deviceNameLength)], encoding: .utf8) else { return nil }
            deviceName = newDeviceName
        }
        else {
            deviceNameLength = 0
            deviceName = nil
        }
        
        let rawDeviceType: Int = Int(data[0] & 7) >> 1
        self.name = deviceName
        self.deviceType = RemoteDeviceInfo.DeviceType.fromRawValue(value: rawDeviceType)
        var offset = 1 + 16
        
        if hasName {
            offset = offset + 1 + deviceNameLength
        }
        
        var qrCodeData: Data? = nil
        
        // read TLV records, if any
        while data.count - offset > 2 {
            let type = data[offset]
            let length = Int(data[offset+1])
            offset = offset + 2
            if data.count - offset >= length{
                // QR code data
                if type == 1 {
                    qrCodeData = data.subdata(in: offset..<offset + length)
                }
                
                offset = offset + length
            }
        }
        
        self.qrCodeData = qrCodeData
    }

    
    func serialize() -> Data {
        // 1 byte: Version(3 bits)|Visibility(1 bit)|Device Type(3 bits)|Reserved(1 bits)
        // Device types: unknown=0, phone=1, tablet=2, laptop=3
        var endpointInfo: [UInt8] = [UInt8(deviceType.rawValue << 1)]
        // 16 bytes: unknown random bytes
        for _ in 0 ... 15 {
            endpointInfo.append(UInt8.random(in: 0 ... 255))
        }
        // Device name in UTF-8 prefixed with 1-byte length
        var nameChars = [UInt8]((name ?? "").utf8)
        if nameChars.count > 255 {
            nameChars = [UInt8](nameChars[0 ..< 255])
        }
        endpointInfo.append(UInt8(nameChars.count))
        for ch in nameChars {
            endpointInfo.append(UInt8(ch))
        }
        return Data(endpointInfo)
    }
}


public enum NearbyError: Error {
    case protocolError(_ message: String)
    case requiredFieldMissing(_ message: String)
    case ukey2
    case packetFilterError
    case firewallError
    case inputOutput
    case canceled(reason: CancellationReason)

    public enum CancellationReason {
        case userRejected, userCanceled, notEnoughSpace, unsupportedType, timedOut
        
        public func localizedDescription() -> String {
            switch self {
                case .userRejected:
                    "TransferDeclined".localized()
                case .userCanceled:
                    "TransferCanceled".localized()
                case .notEnoughSpace:
                    "NotEnoughSpace".localized()
                case .unsupportedType:
                    "UnsupportedType".localized()
                case .timedOut:
                    "TransferTimedOut".localized()
                }
        }
    }
}
