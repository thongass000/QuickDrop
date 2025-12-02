//
//  ApIsolationTester.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation
import Network
import LUI

class DeviceToDeviceHeuristicScanner {
    private let scanQueue = DispatchQueue(label: "DeviceToDeviceScanQueue")
    private var reachableIPs = [String]()
    private var totalToScan = 0
    private var completion: ((Bool) -> Void)?
    
    /// Start scanning the subnet for reachable peers.
    /// - Parameters:
    ///   - baseSubnet: e.g. `"192.168.1"` — if nil, will auto-detect
    ///   - completion: true if any peer device was reachable
    func scan(subnet baseSubnet: String? = nil, port: UInt16 = 80, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        let subnet = baseSubnet ?? Self.getLocalSubnetPrefix() ?? "192.168.1"
        let ipsToScan = (2...254).map { "\(subnet).\($0)" }
        totalToScan = ipsToScan.count
        
        for ip in ipsToScan {
            testConnection(to: ip, port: port)
        }

        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.finish()
        }
    }
    
    private func testConnection(to ip: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: nwPort, using: .tcp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.reachableIPs.append(ip)
                self.finish()
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: scanQueue)
    }

    private func finish() {
        completion?(reachableIPs.count > 0)
        completion = nil
    }

    /// Attempts to detect the local subnet prefix (e.g., "192.168.0")
    private static func getLocalSubnetPrefix() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr!.pointee.ifa_next }
                let interface = ptr!.pointee
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET),
                   let name = String(validatingUTF8: interface.ifa_name),
                      name == getActiveNetworkInterface() {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    if let ip = String(validatingUTF8: hostname),
                       let lastDot = ip.lastIndex(of: ".") {
                        freeifaddrs(ifaddr)
                        
                        let result = String(ip[..<lastDot])
                        
                        log("[LUI] Found local subnet prefix: \(result) for interface \(name)")
                        
                        return result
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return nil
    }
}
