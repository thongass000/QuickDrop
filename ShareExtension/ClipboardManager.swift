//
//  ClipboardManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 17.05.25.
//

import Foundation
import AppKit

class ClipboardManager {
    
    static func saveClipboardToTempFile() -> URL? {
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string) ?? ""
        
        return saveTextToTempFile(text: clipboardString)
    }
    
    static func saveTextToTempFile(text: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("Clipboard".localized() + ".txt")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            log("Failed to write file: \(error)")
            return nil
        }
    }
}
