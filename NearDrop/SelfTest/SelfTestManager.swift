//
//  SelfTestManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.05.25.
//

import Foundation
import Network

class SelfTestManager {
    
    static func run() {
        
        let tester = FirewallSelfTest()
        tester.testLocalLoopbackConnection { allowed in
            if allowed {
                print("✅ Incoming connections appear allowed (no firewall or allowed exception).")
            } else {
                print("❌ Incoming connections may be blocked (firewall or system policy).")
            }
        }
        
        let tester2 = MDNSSelfTest()
        tester2.testBonjourAvailability { available in
            if available {
                print("✅ mDNS is working — multicast DNS responses received.")
            } else {
                print("❌ mDNS seems blocked — possibly by network or router settings.")
            }
        }
        
        let scanner = DeviceToDeviceHeuristicScanner()
        scanner.scan { allowed in
            if allowed {
                print("✅ Device-to-device likely allowed (peer responded on LAN).")
            } else {
                
                let scanner2 = IPv6DeviceScanner()
                scanner2.scan(interface: "en0") { devices in
                    if devices.isEmpty {
                        print("❌ No local devices responded — peer-to-peer may be blocked.")
                    } else {
                        print("✅ Found IPv6 devices (excluding router):")
                        for ip in devices {
                            print("  • \(ip)")
                        }
                    }
                }
            }
        }
        
        let port: UInt16 = 43210
        let packetCount = 10  // 32K packets
        let packetSize = 512 * 1024        // Each packet = UInt32
        let totalSize = packetCount * packetSize

        let server = TCPSelfTestServer()
        let client = TCPSelfTestClient()

        server.start(port: NWEndpoint.Port(rawValue: port)!, expectedPackets: packetCount) { success, report in
            print(success ? "✅ Success: \(report)" : "❌ Failure: \(report)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            client.sendSequentialPackets(to: port, count: packetCount)
        }
    }
}
