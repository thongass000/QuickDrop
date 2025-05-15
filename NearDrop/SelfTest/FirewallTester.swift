//
//  FirewallTester.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation
import Network


class FirewallSelfTest {
    private var listener: NWListener?
    private var didReceiveResponse = false

    func testLocalLoopbackConnection(timeout: TimeInterval = 3.0, completion: @escaping (Bool) -> Void) {
        // Step 1: Create a listener on a random available port
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: 0) // 0 = auto-select available port
        } catch {
            print("Failed to create listener: \(error)")
            completion(false)
            return
        }

        listener?.stateUpdateHandler = { newState in
            if case .ready = newState {
                // Step 2: Once listener is ready, connect to it via loopback
                guard let port = self.listener?.port else {
                    completion(false)
                    return
                }

                let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        self.didReceiveResponse = true
                        connection.cancel()
                        self.listener?.cancel()
                        completion(true)
                    case .failed, .cancelled:
                        if !self.didReceiveResponse {
                            completion(false)
                        }
                    default:
                        break
                    }
                }

                connection.start(queue: .main)
            }
        }

        listener?.newConnectionHandler = { newConnection in
            newConnection.cancel() // We just need to know we can connect
        }

        listener?.start(queue: .main)

        // Step 3: Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if !self.didReceiveResponse {
                self.listener?.cancel()
                completion(false)
            }
        }
    }
}
