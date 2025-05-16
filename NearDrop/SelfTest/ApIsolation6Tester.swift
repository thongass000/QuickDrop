//
//  ApIsolation6Tester.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation
import Network

class IPv6DeviceScanner {
    /// Scans for IPv6 devices using `ping6 ff02::1` multicast on the given interface.
    /// - Parameters:
    ///   - timeout: How long to wait for replies (default 2 seconds).
    ///   - completion: Callback with a list of detected device IPs (excluding router).
    func scan(timeout: TimeInterval = 2.0, completion: @escaping ([String]) -> Void) {
        
    
        let interface = getActiveNetworkInterface() ?? "en0"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping6")
        process.arguments = ["-I", interface, "-c", "2", "ff02::1"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let lines = output
                .components(separatedBy: "\n")
                .filter { $0.contains("bytes from") }

            let ips = lines.compactMap { line -> String? in
                let match = line.components(separatedBy: " ").first(where: { $0.contains(":") && !$0.contains("ff02") })
                return match?.trimmingCharacters(in: .punctuationCharacters)
            }

            // Heuristic: Router is often the first responder — exclude the first
            let uniqueIPs = Array(Set(ips))
            let withoutRouter = Array(uniqueIPs.dropFirst())

            completion(withoutRouter)
        }

        do {
            try process.run()
        } catch {
            log("Failed to run ping6: \(error)")
            completion([])
        }
    }
}
