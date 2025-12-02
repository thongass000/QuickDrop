//
//  ActiveNetworkInterface.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.05.25.
//

import Foundation
import LUI

/// Returns the name of the currently active network interface (e.g. "en0", "en1")
func getActiveNetworkInterface() -> String? {
    let process = Process()
    let pipe = Pipe()

    process.standardOutput = pipe
    process.standardError = Pipe() // Ignore errors as in `2>/dev/null`
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", "route get default 2>/dev/null | awk '/interface: / {print $2}'"]

    do {
        try process.run()
    } catch {
        log("Failed to run process: \(error)")
        return nil
    }

    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
        return output
    }

    return nil
}
