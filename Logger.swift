//
//  Logger.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.02.25.
//

import Foundation
import os

fileprivate let loggerQueue = DispatchQueue(label: "loggerQueue", qos: .utility)

/// Manages logging functionality
final class LogManager {
    
    /// The URL of the log file
    let logFileURL: URL?
    
    /// Shared instance
    public static let sharedInstance = LogManager()
    
    @Published var loggingEnabled = true

    /// Private initializer
    private init() {
        // Use the App Group container
        let directory = getAppGroupDirectory()
        
        // Create file name from date
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateString = formatter.string(from: Date())
        let fileName = "\(dateString).log"
        
        // Full path in app group container
        self.logFileURL = directory?.appendingPathComponent(fileName)
    }
    
    /// Writes a specified string to the log file.
    func writeToFile(string: String) {
        guard let logFileURL = logFileURL else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        guard let data = (timestamp + " - " + string + "\n").data(using: .utf8) else { return }

        loggerQueue.async {
            let fileManager = FileManager.default
            
            if !fileManager.fileExists(atPath: logFileURL.path) {
                // Clean up older logs
                self.deleteLogs()
                // Create file atomically
                try? data.write(to: logFileURL, options: .atomicWrite)
                return
            }

            // Atomic append with file locking using FileHandle
            do {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                defer { try? fileHandle.close() }

                // Locking is handled by the serial dispatch queue
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: data)
            } catch {
                print("[Logger] Failed to write to log file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Gets the contents of the log file.
    func getLogString() -> String {
        guard let logFileURL = logFileURL else { return "" }
        do {
            return try String(contentsOf: logFileURL, encoding: .utf8)
        } catch {
            log("[LUI] Error reading file: \(error.localizedDescription)")
            return ""
        }
    }

    /// Deletes all log files in the shared container.
    func deleteLogs() {
        log("[LUI] Deleting all logs...")
        
        guard let directory = getAppGroupDirectory() else { return }
        let fileManager = FileManager.default
        
        guard let allFiles = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        
        let logFiles = allFiles.filter { $0.pathExtension == "log" }
        for file in logFiles {
            do {
                log("[LUI] Removing \(file.lastPathComponent)")
                try fileManager.removeItem(at: file)
            } catch {
                print("[Logger] Failed to delete file: \(error.localizedDescription)")
            }
        }
    }
}

/// Logs a specified string
public func log(_ text: String) {
    let logger = LogManager.sharedInstance
    
    if logger.loggingEnabled {
        loggerQueue.async {
            print(text)
#if !os(tvOS)
            let isAppExtension = Bundle.main.bundlePath.hasSuffix(".appex")
            let prefix = isAppExtension ? "[EXT]" : "[APP]"
            logger.writeToFile(string: "\(prefix) \(text)")
#endif
        }
    }
}

/// Returns the shared App Group directory
fileprivate func getAppGroupDirectory() -> URL? {
    let groupIdentifier = "group.com.leonboettger.neardrop"
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
}
