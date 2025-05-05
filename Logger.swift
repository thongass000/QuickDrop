//
//  Logger.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.02.25.
//

import Foundation
import os

fileprivate let loggerQueue = DispatchQueue(label: "loggerQueue")

/// Manages logging functionality
final class LogManager {
    
    /// The URL of the log file
    let logFileURL: URL?
    
    /// The private initializer
    private init() {
        
        /// Get documents directory
        let directory = getDocumentsDirectory()
        
        /// Create file name from date
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateString = formatter.string(from: Date())
        let fileName = "\(dateString).log"
        
        /// Create file URL from file name
        self.logFileURL = directory.appendingPathComponent(fileName)
    }
    
    /// The shared instance.
    public static let sharedInstance = LogManager()
    @Published var loggingEnabled = true
    
    
    /// Writes a specified string to the log file.
    func writeToFile(string: String) {
        
        /// Make sure the URL is not nil
        guard let logFileURL = logFileURL else {
            return
        }
        
        /// Get current timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        /// Create data from string and timestamp
        guard let data = (timestamp + " - " + string + "\n").data(using: .utf8) else { return }

        /// a log file exists already
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            
            /// we try to get a handle to write to the log file
            if let file = try? FileHandle(forWritingTo: logFileURL) {
                
                /// go to end of file
                file.seekToEndOfFile()
                
                /// write string to end
                file.write(data)
                
                ///close file
                file.closeFile()
            }
        } else {
            
            /// Clean up older logs
            deleteLogs()
            
            /// create new log file
            try? data.write(to: logFileURL, options: .atomicWrite)
        }
    }
    
    func getLogString() -> String {

        if let logFileURL = logFileURL {
            let fileURL = URL(fileURLWithPath: logFileURL.path)
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                return String(content)
                
            } catch {
                log("[LUI] Error reading file: \(error.localizedDescription)")
            }
        }
        return ""
    }
    
    /// Deletes all log files.
    func deleteLogs() {
        
        log("[LUI] Deleting all logs...")
        
        let fileManager = FileManager.default

        let documentsDirectory = getDocumentsDirectory()
        
        guard let allFiles = try? fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        let logFiles = allFiles.filter { $0.pathExtension.elementsEqual("log") }
        
        for file in logFiles {
            
            do {
                log("[LUI] Removing \(file.description)")
                try fileManager.removeItem(at: file)
                
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}


/// Logs a specified string.
public func log(_ text: String) {
    
    let logger = LogManager.sharedInstance
    
    if logger.loggingEnabled {
        loggerQueue.async {
            print(text)
            
            // Weird bug?
#if !os(tvOS)
            logger.writeToFile(string: text)
#endif
        }
    }
}


/// Returns the URL of the documents directory.
func getDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
}

