//
//  ApIsolationTester.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation
import Network
import LUI

final class DeviceToDeviceHeuristicScanner {
    static let shared = DeviceToDeviceHeuristicScanner()
    private init() {}

    private enum ScanMode {
        case peerReachability       // true only if some peer is reachable
        case localNetworkAccess     // true if EHOSTDOWN seen (or ready)
    }

    private let scanQueue = DispatchQueue(label: "DeviceToDeviceScanQueue")

    private var reachableIPs: [String] = []
    private var activeConnections: [NWConnection] = []

    private var completion: ((Bool) -> Void)?
    private var finished = false
    private var currentMode: ScanMode = .peerReachability

    // Cache: once true, stays true for subsequent calls
    private var cachedLocalNetworkAccess = false

    private var peerReachableCached: Bool { !reachableIPs.isEmpty }

    // MARK: - Public API

    /// Start scanning the subnet for reachable peers.
    /// - Returns: true if any peer device was reachable (same semantics as before).
    func scan(subnet baseSubnet: String? = nil,
              port: UInt16 = 80,
              timeout: TimeInterval = 10.0,
              completion: @escaping (Bool) -> Void) {

        if peerReachableCached {
            completion(true)
            return
        }

        startScan(
            mode: .peerReachability,
            subnet: baseSubnet,
            port: port,
            timeout: timeout,
            completion: completion
        )
    }

    /// Returns true if:
    /// - cached value is true, OR
    /// - during a scan at least one host produces `.waiting(.posix(.EHOSTDOWN))`.
    ///
    /// As soon as EHOSTDOWN is observed, returns true immediately.
    /// Otherwise waits until timeout (default 10s) and returns false.
    func hasLocalNetworkAccess(subnet baseSubnet: String? = nil,
                               port: UInt16 = 80,
                               timeout: TimeInterval = 10.0,
                               completion: @escaping (Bool) -> Void) -> Bool {

        if cachedLocalNetworkAccess {
            return true
        }

        startScan(
            mode: .localNetworkAccess,
            subnet: baseSubnet,
            port: port,
            timeout: timeout,
            completion: completion
        )
        return false
    }

    // MARK: - Core scan logic

    private func startScan(mode: ScanMode,
                           subnet baseSubnet: String?,
                           port: UInt16,
                           timeout: TimeInterval,
                           completion: @escaping (Bool) -> Void) {

        scanQueue.async {
            // Cancel any in-flight scan to keep behavior deterministic.
            self.cancelActiveConnections()

            self.currentMode = mode
            self.completion = completion
            self.finished = false

            let subnet = baseSubnet ?? Self.getLocalSubnetPrefix() ?? "192.168.1"
            let ipsToScan = (2...254).map { "\(subnet).\($0)" }

            for ip in ipsToScan {
                self.testConnection(to: ip, port: port)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                self.finish(result: self.resultForCurrentModeOnTimeout())
            }
        }
    }

    private func testConnection(to ip: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        let connection = NWConnection(host: NWEndpoint.Host(ip), port: nwPort, using: .tcp)
        activeConnections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                self.scanQueue.async {
                    self.reachableIPs.append(ip)
                    // If a TCP connection succeeds, local network access is effectively confirmed as well.
                    self.cachedLocalNetworkAccess = true

                    // For scan(): success means peer reachable.
                    // For hasLocalNetworkAccess(): success also means local network access.
                    self.finish(result: true)
                }
                connection.cancel()

            case .waiting(let error):
                // "Host is down" is treated as a strong signal that local-network traffic is possible,
                // even if the specific host doesn't respond.
                if error == .posix(.EHOSTDOWN) {
                    self.scanQueue.async {
                        self.cachedLocalNetworkAccess = true

                        if self.currentMode == .localNetworkAccess {
                            self.finish(result: true)
                        }
                    }
                }

            case .failed, .cancelled:
                // Ignore; scan completes via early success or timeout.
                break

            default:
                break
            }
        }

        connection.start(queue: scanQueue)
    }

    private func resultForCurrentModeOnTimeout() -> Bool {
        switch currentMode {
        case .peerReachability:
            return peerReachableCached
        case .localNetworkAccess:
            return cachedLocalNetworkAccess
        }
    }

    private func finish(result: Bool) {
        scanQueue.async {
            guard !self.finished else { return }
            self.finished = true

            let completion = self.completion
            self.completion = nil

            self.cancelActiveConnections()

            DispatchQueue.main.async {
                completion?(result)
            }
        }
    }

    private func cancelActiveConnections() {
        for c in activeConnections { c.cancel() }
        activeConnections.removeAll()
    }

    // MARK: - Subnet detection

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
                    getnameinfo(interface.ifa_addr,
                                socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname,
                                socklen_t(hostname.count),
                                nil,
                                0,
                                NI_NUMERICHOST)

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
