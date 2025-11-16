//
//  EXIFUtils.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.11.25.
//

import Foundation
import ImageIO

struct EXIFUtils {
    
    /// Applies EXIF timestamps to a given file or directory.
    static func applyEXIFTimestamps(at url: URL) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        
        if isDir.boolValue {
            // It's a directory — enumerate files
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey]) {
                for case let fileURL as URL in enumerator {
                    guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                    applyEXIFTimestamp(to: fileURL)
                }
            }
        } else {
            // It's a single file
            applyEXIFTimestamp(to: url)
        }
    }
    
    
    /// Applies EXIF timestamp (if available) to a single file
    private static func applyEXIFTimestamp(to fileURL: URL) {
        guard let exifDate = exifOriginalDate(from: fileURL) else {
            return
        }

        do {
            // Set the "creation date"
            try FileManager.default.setAttributes([.creationDate: exifDate], ofItemAtPath: fileURL.path)
        }
        catch {
            log("[EXIFUtils] Failed to set file attributes for \(fileURL.path): \(error)")
        }
    }
    
    
    /// Returns the EXIF original date of an image file, adjusted to the current time zone.
    private static func exifOriginalDate(from url: URL) -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone.current  // Use the current device time zone
        return formatter.date(from: dateString)
    }
}
