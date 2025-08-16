//
//  NearbyConnectionManager.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

#if os(iOS)
import UIKit
#endif

import Foundation
import Network
import System
import SwiftECC
import CryptoKit

public class NearbyConnectionManager: NSObject, NetServiceDelegate, InboundNearbyConnectionDelegate, OutboundNearbyConnectionDelegate {
    
    private let sleepManager = SleepManager.shared
    private var tcpListener: NWListener
    private var mdnsServices: [NetService] = []
    private var incomingConnections: [String: InboundNearbyConnection] = [:]
    private var foundServices: [String: FoundServiceInfo] = [:]
    private var shareExtensionDelegates: [ShareExtensionDelegate] = []
    private var outgoingTransfers: [String: OutgoingTransferInfo] = [:]
    private var startedDeviceDiscovery = false
    private var browsers: [NWBrowser] = []
    private let serviceTypes = ["_FC9F5ED42C8A._tcp."]
    private var qrCodePrivateKey: ECPrivateKey?
    private var qrCodeAdvertisingToken: Data?
    private var qrCodeNameEncryptionKey: SymmetricKey?
    
    public let endpointID: [UInt8] = generateEndpointID()
    public var mainAppDelegate: (any MainAppDelegate)?
    public static let shared = NearbyConnectionManager()
    
    
    override init() {
        tcpListener = try! NWListener(using: NWParameters(tls: .none))
        super.init()
    }
    
    
    public func becomeVisible() {
        startTCPListener()
    }
    
    
    private func startTCPListener() {
        tcpListener.stateUpdateHandler = { (state: NWListener.State) in
            if case .ready = state {
                self.initMDNS()
            }
        }
        tcpListener.newConnectionHandler = { (connection: NWConnection) in
            let id = UUID().uuidString
            let conn = InboundNearbyConnection(connection: connection, id: id)
            self.incomingConnections[id] = conn
            conn.delegate = self
            conn.start()
        }
        tcpListener.start(queue: .global(qos: .utility))
    }
    
    
    private static func generateEndpointID() -> [UInt8] {
        let userDefaultsKey = UserDefaultsKeys.endpointID.rawValue
        
        // Try to retrieve from UserDefaults
        if let savedString = UserDefaults.standard.string(forKey: userDefaultsKey),
           let savedData = savedString.data(using: .utf8)
        {
            return [UInt8](savedData)
        }
        
        // Generate a new random ID
        var id: [UInt8] = []
        let alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".compactMap { UInt8($0.asciiValue!) }
        for _ in 0 ..< 4 {
            id.append(alphabet[Int.random(in: 0 ..< alphabet.count)])
        }
        
        // Save to UserDefaults as String
        let idString = String(bytes: id, encoding: .utf8) ?? ""
        UserDefaults.standard.set(idString, forKey: userDefaultsKey)
        
        return id
    }
    
    
    private func initMDNS() {
        let nameBytes: [UInt8] = [
            0x23, // PCP
            endpointID[0], endpointID[1], endpointID[2], endpointID[3],
            0xFC, 0x9F, 0x5E, // Service ID hash
            0, 0,
        ]
        
        let name = Data(nameBytes).urlSafeBase64EncodedString()
        let port = Int32(tcpListener.port!.rawValue)
        
        mdnsServices = serviceTypes.map { serviceType in
            let service = NetService(domain: "", type: serviceType, name: name, port: port)
            service.delegate = self
            service.setTXTRecord(NetService.data(fromTXTRecord: [
                "n": getEndpointInfo().serialize().urlSafeBase64EncodedString().data(using: .utf8)!,
            ]))
            service.publish()
            return service
        }
    }
    
    
    func getEndpointInfo() -> EndpointInfo {
#if os(macOS)
        let endpointInfo = EndpointInfo(name: Host.current().localizedName ?? "Mac", deviceType: .computer)
#else
        let endpointInfo = EndpointInfo(name: UIDevice.current.name, deviceType: .phone)
#endif
        
        return endpointInfo
    }
    
    
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo, connection _: InboundNearbyConnection) {
        mainAppDelegate?.obtainUserConsent(for: transfer, from: device)
    }
    
    
    func connectionWasTerminated(connection: InboundNearbyConnection, error: Error?) {
        incomingConnections.removeValue(forKey: connection.id)
        
        if !connection.wasRejected {
            mainAppDelegate?.incomingTransfer(id: connection.id, from: connection.remoteDeviceInfo ?? RemoteDeviceInfo(name: "??", type: .unknown), didFinishWith: error)
        }
    }
    
    
    public func submitUserConsent(transferID: String, accept: Bool, storeInTemp: Bool = false) {
        guard let conn = incomingConnections[transferID] else { return }
        
        log("[NearbyConnectionManager] Submitting user consent for transfer \(transferID), accepted: \(accept), store in temp: \(storeInTemp)")
        conn.submitUserConsent(accepted: accept, storeInTemp: storeInTemp)
    }
    
    
    public func startDeviceDiscovery() {
        
        if !startedDeviceDiscovery {
            startedDeviceDiscovery = true
            foundServices.removeAll()
            
            log("[NearbyConnectionManager] Starting device discovery")
            
            if browsers.isEmpty {
                for type in serviceTypes {
                    log("[NearbyConnectionManager] Starting browser for type \(type)")
                    
                    let browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: .tcp)
                    browser.browseResultsChangedHandler = { _, changes in
                        for change in changes {
                            switch change {
                            case let .added(res):
                                self.addFoundDevice(service: res)
                            case let .removed(res):
                                self.removeFoundDevice(service: res)
                            default:
                                log("[NearbyConnectionManager] Ignoring change \(change)")
                            }
                        }
                    }
                    browser.start(queue: .main)
                    browsers.append(browser)
                }
            }
        }
    }
    
    
    public func stopDeviceDiscovery() {
        if startedDeviceDiscovery {
            
            log("Stopping device discovery")
            
            for browser in browsers {
                browser.cancel()
            }
            
            browsers.removeAll()
            startedDeviceDiscovery = false
        }
    }
    
    
    public func addShareExtensionDelegate(_ delegate: ShareExtensionDelegate) {
        shareExtensionDelegates.append(delegate)
        for service in foundServices.values {
            guard let device = service.device else { continue }
            delegate.addDevice(device: device)
        }
    }
    
    
    public func removeShareExtensionDelegate(_ delegate: ShareExtensionDelegate) {
        shareExtensionDelegates.removeAll(where: { $0 === delegate })
    }
    
    
    public func cancelOutgoingTransfer(id: String) {
        guard let transfer = outgoingTransfers[id] else { return }
        transfer.connection.cancel()
    }
    
    
    private func endpointID(for service: NWBrowser.Result) -> String? {
        guard case let NWEndpoint.service(name: serviceName, type: _, domain: _, interface: _) = service.endpoint else { return nil }
        guard let nameData = Data.dataFromUrlSafeBase64(serviceName) else { return nil }
        guard nameData.count >= 10 else { return nil }
        let pcp = nameData[0]
        guard pcp == 0x23 else { return nil }
        let endpointID = String(data: nameData.subdata(in: 1 ..< 5), encoding: .ascii)!
        let serviceIDHash = nameData.subdata(in: 5 ..< 8)
        guard serviceIDHash == Data([0xFC, 0x9F, 0x5E]) else { return nil }
        return endpointID
    }
    
    
    private func addFoundDevice(service: NWBrowser.Result) {
        log("[NearbyConnectionManager] Found Service \(service)")
        for interface in service.interfaces {
            if case .loopback = interface.type {
                return
            }
        }
        guard let endpointID = endpointID(for: service) else { return }
        var foundService = FoundServiceInfo(service: service)
        
        guard case let NWBrowser.Result.Metadata.bonjour(txtRecord) = service.metadata else { return }
        guard let endpointInfoEncoded = txtRecord.dictionary["n"] else { return }
        guard let endpointInfoData = Data.dataFromUrlSafeBase64(endpointInfoEncoded) else { return }
        guard var endpointInfo = EndpointInfo(data: endpointInfoData) else { return }
        var deviceInfo: RemoteDeviceInfo?
        
        if let _ = endpointInfo.name {
            deviceInfo = addFoundDevice(foundService: &foundService, endpointInfo: endpointInfo, endpointID: endpointID)
        }
        
        if let qrData = endpointInfo.qrCodeData, let qrCodeAdvertisingToken = qrCodeAdvertisingToken, let qrCodeNameEncryptionKey = qrCodeNameEncryptionKey {
            
            log("[NearbyConnectionManager] Device has QR data: \(qrData.base64EncodedString()), advertising token is \(qrCodeAdvertisingToken.base64EncodedString())")
            
            if qrData == qrCodeAdvertisingToken {
                if let deviceInfo = deviceInfo {
                    for delegate in shareExtensionDelegates {
                        delegate.startTransferWithQrCode(device: deviceInfo)
                    }
                }
            }
            else if qrData.count > 28 {
                do {
                    let box = try AES.GCM.SealedBox(combined: qrData)
                    let decryptedName = try AES.GCM.open(box, using: qrCodeNameEncryptionKey, authenticating: qrCodeAdvertisingToken)
                    guard let name = String.init(data: decryptedName, encoding: .utf8) else { return }
                    endpointInfo.name = name
                    let deviceInfo = addFoundDevice(foundService: &foundService, endpointInfo: endpointInfo, endpointID: endpointID)
                    for delegate in shareExtensionDelegates {
                        delegate.startTransferWithQrCode(device: deviceInfo)
                    }
                } catch {
                    log("[NearbyConnectionManager] Error decrypting QR code data of an invisible device: \(error)")
                }
            }
        }
    }
    
    
    private func addFoundDevice(foundService: inout FoundServiceInfo, endpointInfo: EndpointInfo, endpointID: String) -> RemoteDeviceInfo {
        let deviceInfo = RemoteDeviceInfo(info: endpointInfo, id: endpointID)
        foundService.device = deviceInfo
        foundServices[endpointID] = foundService
        
        for delegate in shareExtensionDelegates {
            delegate.addDevice(device: deviceInfo)
        }
        
        return deviceInfo
    }
    
    
    private func removeFoundDevice(service: NWBrowser.Result) {
        guard let endpointID = endpointID(for: service) else { return }
        guard let _ = foundServices.removeValue(forKey: endpointID) else { return }
        for delegate in shareExtensionDelegates {
            delegate.removeDevice(id: endpointID)
        }
    }
    
    
    public func generateQrCodeKey() -> String{
        let domain = Domain.instance(curve: .EC256r1)
        let (pubKey, privKey) = domain.makeKeyPair()
        qrCodePrivateKey = privKey
        var keyData = Data()
        keyData.append(contentsOf: [0, 0, 2])
        let keyBytes = Data(pubKey.w.x.asSignedBytes())
        // Sometimes, for some keys, there will be a leading zero byte. Strip that, Android really hates it (it breaks the endpoint info)
        keyData.append(keyBytes.suffixOfAtMost(numBytes: 32))
        
        let ikm = SymmetricKey(data: keyData)
        qrCodeAdvertisingToken = HKDF.deriveKey(ikm: ikm, salt: Data(), info: "advertisingContext".data(using: .utf8)!, outputLength: 16).data()
        qrCodeNameEncryptionKey = HKDF.deriveKey(ikm: ikm, salt: Data(), info: "encryptionKey".data(using: .utf8)!, outputLength: 16)
        
        return keyData.urlSafeBase64EncodedString()
    }
    
    
    public func startOutgoingTransfer(deviceID: String, delegate: ShareExtensionDelegate, urls: [URL], textToSend: String?) {
        log("Starting outgoing transfer to \(deviceID)")
        guard let info = foundServices[deviceID] else { return }
        
        do {
            let localUrls = try saveFilesToTemp(urls: urls)
            
            let tcp = NWProtocolTCP.Options()
            tcp.noDelay = true
            let nwconn = NWConnection(to: info.service.endpoint, using: NWParameters(tls: .none, tcp: tcp))
            
            let conn = OutboundNearbyConnection(connection: nwconn, id: deviceID, urlsToSend: localUrls, textToSend: textToSend)
            conn.delegate = self
            conn.qrCodePrivateKey = qrCodePrivateKey
            let transfer = OutgoingTransferInfo(service: info.service, device: info.device!, connection: conn, delegate: delegate)
            outgoingTransfers[deviceID] = transfer
            conn.start()
        } catch {
            log("[NearbyConnectionManager] Error zipping URLs: \(error)")
            shareExtensionDelegates.forEach { delegate in
                delegate.connectionFailed(with: error)
            }
        }
    }
    
    
    func outboundConnectionWasEstablished(connection: OutboundNearbyConnection) {
        guard let transfer = outgoingTransfers[connection.id] else { return }
        DispatchQueue.main.async {
            transfer.delegate.connectionWasEstablished(pinCode: connection.pinCode!)
        }
    }
    
    
    func outboundConnectionTransferAccepted(connection: OutboundNearbyConnection) {
        guard let transfer = outgoingTransfers[connection.id] else { return }
        DispatchQueue.main.async {
            transfer.delegate.transferAccepted()
        }
    }
    
    
    func outboundConnection(connection: OutboundNearbyConnection, transferProgress: Double) {
        guard let transfer = outgoingTransfers[connection.id] else { return }
        DispatchQueue.main.async {
            transfer.delegate.transferProgress(progress: transferProgress)
        }
    }
    
    
    func outboundConnection(connection: OutboundNearbyConnection, failedWithError: Error) {
        guard let transfer = outgoingTransfers[connection.id] else { return }
        DispatchQueue.main.async {
            transfer.delegate.connectionFailed(with: failedWithError)
        }
        outgoingTransfers.removeValue(forKey: connection.id)
    }
    
    
    func outboundConnectionTransferFinished(connection: OutboundNearbyConnection) {
        guard let transfer = outgoingTransfers[connection.id] else { return }
        DispatchQueue.main.async {
            transfer.delegate.transferFinished()
        }
        outgoingTransfers.removeValue(forKey: connection.id)
    }
    
    
    public func getActiveConnectionsCount() -> Int {
        return incomingConnections.count + outgoingTransfers.count
    }
    
    
    private func saveFilesToTemp(urls: [URL]) throws -> [URL] {
        
        var modifiedUrls = [URL]()
        
        for url in urls {
            
            // if url is no file url or already in inside temp directory, do nothing
            if url.isFileURL && !url.standardizedFileURL.path.contains(FileManager.default.temporaryDirectory.standardizedFileURL.path) {
                
                let accessSuccess = url.startAccessingSecurityScopedResource()
                
                if !accessSuccess {
                    log("[NearbyConnectionManager] Could not access security scoped resource at \(url)")
                }
                
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                    let zipUrl = try Zip.createAtTemporaryDirectory(zipFilename: url.lastPathComponent, fromDirectory: url)
                    
                    modifiedUrls.append(zipUrl)
                }
                else {
                    // Copy single file to temp directory
                    let tempUrl = FileManager.default.temporaryDirectory
                        .appendingPathComponent(url.lastPathComponent)
                    // Remove if already exists
                    if FileManager.default.fileExists(atPath: tempUrl.path) {
                        try FileManager.default.removeItem(at: tempUrl)
                    }
                    try FileManager.default.copyItem(at: url, to: tempUrl)
                    modifiedUrls.append(tempUrl)
                }
                
                if accessSuccess {
                    url.stopAccessingSecurityScopedResource()
                }
                
            }
            else {
                log("[NearbyConnectionManager] File URL \(url) does not point to a security scoped resource")
                modifiedUrls.append(url)
            }
        }
        
        return modifiedUrls
    }
    
    
    // -- MARK: - Internal Data Model
    
    private struct FoundServiceInfo {
        let service: NWBrowser.Result
        var device: RemoteDeviceInfo?
    }
    
    
    private struct OutgoingTransferInfo {
        let service: NWBrowser.Result
        let device: RemoteDeviceInfo
        let connection: OutboundNearbyConnection
        let delegate: ShareExtensionDelegate
    }
}
