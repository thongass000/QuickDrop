//
//  TcpSelfTestClient.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation
import Network

class TCPSelfTestClient {
    func sendSequentialPackets(to port: UInt16, count: Int) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
        connection.stateUpdateHandler = { state in
            if state == .ready {
                var allData = Data()
                for i in 0..<count {
                    var value = UInt32(i).bigEndian
                    let packet = Data(bytes: &value, count: 4)
                    allData.append(packet)
                }

                connection.send(content: allData, completion: .contentProcessed { error in
                    if let error = error {
                        print("Client error: \(error)")
                    } else {
                        print("✅ Client sent \(count) packets")
                    }
                    connection.cancel()
                })
            }
        }

        connection.start(queue: .main)
    }
}
