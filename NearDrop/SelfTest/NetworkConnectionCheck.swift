//
//  NetworkConnectionCheck.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.05.25.
//

import Foundation
import SystemConfiguration

/// Returns true if the device is connected to any network (Wi-Fi, Ethernet, etc.)
func isConnectedToNetwork() -> Bool {
    var zeroAddress = sockaddr_in(
        sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
        sin_family: sa_family_t(AF_INET),
        sin_port: 0,
        sin_addr: in_addr(s_addr: 0),
        sin_zero: (0,0,0,0,0,0,0,0)
    )

    guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
            SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
        }
    }) else {
        return false
    }

    var flags = SCNetworkReachabilityFlags()
    if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
        return false
    }

    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)

    return isReachable && !needsConnection
}
