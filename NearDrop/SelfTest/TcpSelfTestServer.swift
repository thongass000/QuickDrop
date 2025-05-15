//
//  TcpSelfTestServer.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation
import Network

class TCPSelfTestServer {
    private var listener: NWListener?
    private var receivedData = Data()
    var onComplete: ((Bool, String) -> Void)?
    private var expectedPackets: Int = 0

    func start(port: NWEndpoint.Port, expectedPackets: Int, onComplete: @escaping (Bool, String) -> Void) {
        self.onComplete = onComplete
        self.expectedPackets = expectedPackets

        do {
            let listener = try NWListener(using: .tcp, on: port)
            self.listener = listener
            listener.newConnectionHandler = { connection in
                connection.start(queue: .main)
                self.receive(on: connection)
            }
            listener.start(queue: .main)
        } catch {
            onComplete(false, "Server failed: \(error.localizedDescription)")
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
            if let data = data {
                self.receivedData.append(data)
            }

            if isComplete || self.receivedData.count >= self.expectedPackets * 4 {
                connection.cancel()
                self.listener?.cancel()
                self.verify()
            } else if error == nil {
                self.receive(on: connection)
            } else {
                self.onComplete?(false, "Receive error: \(String(describing: error))")
            }
        }
    }

    private func verify() {
        var values = [UInt32]()
        let total = receivedData.count / 4
        for i in 0..<total {
            let range = i*4..<i*4+4
            let chunk = receivedData.subdata(in: range)
            let value = chunk.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            values.append(value)
        }

        let expected = Array(0..<UInt32(values.count))
        let dropped = expected.filter { !values.contains($0) }
        let duplicates = Dictionary(grouping: values, by: { $0 }).filter { $1.count > 1 }.keys

        if !dropped.isEmpty || !duplicates.isEmpty || values != expected {
            var issues = [String]()
            if !dropped.isEmpty {
                issues.append("Dropped packets: \(dropped.prefix(10))...")
            }
            if !duplicates.isEmpty {
                issues.append("Duplicates: \(duplicates.prefix(10))")
            }
            if values != expected {
                issues.append("Out-of-order delivery detected.")
            }
            onComplete?(false, issues.joined(separator: " | "))
        } else {
            onComplete?(true, "All packets received in order")
        }
    }
}
