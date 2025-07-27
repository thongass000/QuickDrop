//
//  NearbyConnectionManager.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

import Foundation
import Network
import System


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
        let endpointInfo = EndpointInfo(name: Host.current().localizedName!, deviceType: .computer)

        let port = Int32(tcpListener.port!.rawValue)

        mdnsServices = serviceTypes.map { serviceType in
            let service = NetService(domain: "", type: serviceType, name: name, port: port)
            service.delegate = self
            service.setTXTRecord(NetService.data(fromTXTRecord: [
                "n": endpointInfo.serialize().urlSafeBase64EncodedString().data(using: .utf8)!,
            ]))
            service.publish()
            return service
        }
    }

    
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo, connection _: InboundNearbyConnection) {
        mainAppDelegate?.obtainUserConsent(for: transfer, from: device)
    }
    
    
    func connectionWasTerminated(connection: InboundNearbyConnection, error: Error?) {
        incomingConnections.removeValue(forKey: connection.id)
        
        if !connection.wasRejected {
            mainAppDelegate?.incomingTransfer(id: connection.id, didFinishWith: error)
        }
    }

    
    public func submitUserConsent(transferID: String, accept: Bool, storeInTemp: Bool = false) {
        guard let conn = incomingConnections[transferID] else { return }
        
        log("Submitting user consent for transfer, accepted: \(accept), store in temp: \(storeInTemp)")
        conn.submitUserConsent(accepted: accept, storeInTemp: storeInTemp)
    }

    
    public func startDeviceDiscovery() {
        
        if !startedDeviceDiscovery {
            startedDeviceDiscovery = true
            foundServices.removeAll()

            log("Starting device discovery")

            if browsers.isEmpty {
                for type in serviceTypes {
                    log("Starting browser for type \(type)")

                    let browser = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: .tcp)
                    browser.browseResultsChangedHandler = { _, changes in
                        for change in changes {
                            switch change {
                            case let .added(res):
                                self.addFoundDevice(service: res)
                            case let .removed(res):
                                self.removeFoundDevice(service: res)
                            default:
                                log("Ignoring change \(change)")
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
            for browser in browsers {
                browser.cancel()
            }

            browsers.removeAll()
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
        log("found service \(service)")
        for interface in service.interfaces {
            if case .loopback = interface.type {
                log("ignoring localhost service")
                return
            }
        }
        guard let endpointID = endpointID(for: service) else { return }
        log("service name is valid, endpoint ID \(endpointID)")
        var foundService = FoundServiceInfo(service: service)

        guard case let NWBrowser.Result.Metadata.bonjour(txtRecord) = service.metadata else { return }
        guard let endpointInfoEncoded = txtRecord.dictionary["n"] else { return }
        guard let endpointInfo = Data.dataFromUrlSafeBase64(endpointInfoEncoded) else { return }
        guard endpointInfo.count >= 19 else { return }
        let deviceType = RemoteDeviceInfo.DeviceType.fromRawValue(value: (Int(endpointInfo[0]) >> 1) & 7)
        let deviceNameLength = Int(endpointInfo[17])
        guard endpointInfo.count >= deviceNameLength + 17 else { return }
        guard let deviceName = String(data: endpointInfo.subdata(in: 18 ..< (18 + deviceNameLength)), encoding: .utf8) else { return }

        let deviceInfo = RemoteDeviceInfo(name: deviceName, type: deviceType, id: endpointID)
        foundService.device = deviceInfo
        foundServices[endpointID] = foundService
        for delegate in shareExtensionDelegates {
            delegate.addDevice(device: deviceInfo)
        }
    }

    
    private func removeFoundDevice(service: NWBrowser.Result) {
        guard let endpointID = endpointID(for: service) else { return }
        guard let _ = foundServices.removeValue(forKey: endpointID) else { return }
        for delegate in shareExtensionDelegates {
            delegate.removeDevice(id: endpointID)
        }
    }

    
    public func startOutgoingTransfer(deviceID: String, delegate: ShareExtensionDelegate, urls: [URL], textToSend: String?) {
        guard let info = foundServices[deviceID] else { return }
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let nwconn = NWConnection(to: info.service.endpoint, using: NWParameters(tls: .none, tcp: tcp))
        let conn = OutboundNearbyConnection(connection: nwconn, id: deviceID, urlsToSend: urls, textToSend: textToSend)
        conn.delegate = self
        let transfer = OutgoingTransferInfo(service: info.service, device: info.device!, connection: conn, delegate: delegate)
        outgoingTransfers[deviceID] = transfer
        conn.start()
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
