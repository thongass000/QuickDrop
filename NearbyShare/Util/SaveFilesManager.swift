//
//  SaveFilesManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.07.25.
//

import Foundation
import ImageIO
#if os(macOS)
import AppKit
#else
import LUI
import UIKit
#endif

public class SaveFilesManager {
    
    private init() {
        // remove old temp directory
        
        let tempPath = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default

         do {
             let contents = try fileManager.contentsOfDirectory(at: tempPath, includingPropertiesForKeys: nil)
             
             var didSomething = false
             
             for item in contents {
                 didSomething = true
                 try fileManager.removeItem(at: item)
             }
             
             if didSomething {
                 log("Temporary directory cleared.")
             }
         } catch {
             log("Failed to list contents of temp directory: \(error)")
         }
    }

    public static let shared = SaveFilesManager()

    let tempDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Pending")
    private var securityScopeUrl: URL?

    private var filesFinishedDownloading = [URL]()
    private var filesFinishedDownloadingSinceLastRun = [URL]()
    
    public func registerFileFinishedDownloading(_ fileURL: URL) {
        filesFinishedDownloading.append(fileURL)
        filesFinishedDownloadingSinceLastRun.append(fileURL)
        
        // read out EXIF timestamp and manually set file creation date to it
        applyEXIFTimestamps(at: fileURL)
    }
    
    
    public func movePendingFilesToTarget() {

        if isPlusVersion() {
            do {
                let fileManager = FileManager.default
                let files = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
                
                let target = getSaveDirectory()
                var loggedExecution = false
                
                for file in files {
                    
                    if !loggedExecution {
                        log("Moving pending files to target directory")
                        loggedExecution = true
                    }
                    
                    let fileName = file.lastPathComponent
                    let destinationURL = target.appendingPathComponent(fileName)
                    
                    if !filesFinishedDownloading.contains(destinationURL) {
                        log("File \(file) not finished downloading, skipping")
                        continue
                    }
                    
                    log("Moving file: \(file.lastPathComponent) to \(destinationURL.lastPathComponent)")
                    
                    do {
                        try fileManager.copyItem(at: file, to: destinationURL)
                        
                        let progress = Progress()
                        progress.fileURL = destinationURL
                        progress.totalUnitCount = 10
                        progress.kind = .file
                        progress.isPausable = false
                        #if os(macOS)
                        progress.publish()
                        #endif
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            progress.completedUnitCount = 10
                            #if os(macOS)
                            progress.unpublish()
                            #endif
                        }
                        
                        try fileManager.removeItem(at: file)
                    }
                    catch {
                        log("Error moving file: \(error)")
                    }
                }
                log("Moved all pending files to target directory")
            }
            catch {
                // Pending directory doesn't exist or is empty
            }
        }
        
        if !filesFinishedDownloadingSinceLastRun.isEmpty && !isFileTransferRestricted() {
            
            #if os(macOS)
            if UserDefaults.standard.bool(forKey: UserDefaultsKeys.openFinderAfterReceiving.rawValue) {
                log("Opening \(filesFinishedDownloadingSinceLastRun.count) file(s) in Finder.")
                NSWorkspace.shared.activateFileViewerSelecting(filesFinishedDownloadingSinceLastRun)
            }
            #else
                openDownloadedFilesFolder()
            #endif
            
            // Clear the list of finished files
            filesFinishedDownloadingSinceLastRun.removeAll()
        }

        stopAccessingSecurityScopedResource()
    }
    
    
    #if !os(macOS)
    public func openDownloadedFilesFolder() {
        #if !EXTENSION
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    
        if let documentsUrl = documentsUrl, let sharedUrl = URL(string: "shareddocuments://\(documentsUrl.path)"), UIApplication.shared.canOpenURL(sharedUrl) {
            UIApplication.shared.open(sharedUrl, options: [:])
        }
        else {
            showAlert(title: "CouldNotOpenDocumentsFolder", message: "CouldNotOpenDocumentsFolderDescription")
        }
        #endif
    }
    #endif
    

    public func stopAccessingSecurityScopedResource() {
        guard let url = securityScopeUrl else {
            return
        }

        log("Stopping access to security scoped resource: \(url)")
        url.stopAccessingSecurityScopedResource()
        securityScopeUrl = nil
    }

    
    public func getSaveDirectory() -> URL {
        
        // Not supported on iOS
        #if os(macOS)
        if let securityScopeUrl = securityScopeUrl {
            log("Using existing security scope URL: \(securityScopeUrl)")
            return securityScopeUrl
        }

        if let bookmarkData = UserDefaults.standard.data(forKey: UserDefaultsKeys.saveFolderBookmark.rawValue) {
            var isStale = false
   
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                if !isStale {
                    if url.startAccessingSecurityScopedResource() {
                        log("Successfully accessed security scoped resource: \(url)")

                        securityScopeUrl = url
                        return url
                    }
                } else {
                    log("Bookmark is stale, using default downloads folder.")
                }

            } catch {
                log("Failed to resolve bookmark: \(error), using default downloads folder.")
            }
        }

        do {
            return try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true).resolvingSymlinksInPath()
        } catch {
            fatalError("Failed to get downloads directory: \(error)")
        }
        #else
        // Return the documents directory for iOS
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).resolvingSymlinksInPath()
        } catch {
            fatalError("Failed to get documents directory: \(error)")
        }
        #endif
    }
    
    
    /// Returns the EXIF original date of an image file, adjusted to the current time zone.
    private func exifOriginalDate(from url: URL) -> Date? {
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

    
    /// Applies EXIF timestamps to a given file or directory.
    private func applyEXIFTimestamps(at url: URL) {
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
    private func applyEXIFTimestamp(to fileURL: URL) {
        guard let exifDate = exifOriginalDate(from: fileURL) else {
            return
        }

        // Set the "creation date"
        try? FileManager.default.setAttributes([.creationDate: exifDate], ofItemAtPath: fileURL.path)
    }
}
