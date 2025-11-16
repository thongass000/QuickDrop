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
    static func exifOriginalDate(from url: URL) -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else {
            return nil
        }
        
        let offsetString = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        
        let offsetSeconds = offsetString.flatMap(secondsFromOffsetString)
        if let seconds = offsetSeconds {
            formatter.timeZone = TimeZone(secondsFromGMT: seconds)
        } else {
            // Fallback: treat as device local
            formatter.timeZone = TimeZone.current
        }
        
        return formatter.date(from: dateString)
    }
    
    
    static private func secondsFromOffsetString(_ s: String) -> Int? {
        // Expect formats like "+02:00" or "-05:30"
        guard s.count == 6, (s.first == "+" || s.first == "-") else { return nil }
        let sign = s.first == "-" ? -1 : 1
        let parts = s.dropFirst().split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else { return nil }
        return sign * (hours * 3600 + minutes * 60)
    }
}
