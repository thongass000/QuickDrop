//
//  SaveFilesManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.07.25.
//

import Foundation
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
                 log("[SaveFilesManager] Temporary directory cleared.")
             }
         } catch {
             log("[SaveFilesManager] Failed to list contents of temp directory: \(error)")
         }
    }
    

    public static let shared = SaveFilesManager()
    
    private var securityScopeUrl: URL?
    private var filesFinishedDownloadingSinceLastRun = [URL]()
    
    public func registerFileFinishedDownloading(_ fileURL: URL) {
        filesFinishedDownloadingSinceLastRun.append(fileURL)
    }
    
    
    public func movePendingFilesToTarget() {
        
        if !filesFinishedDownloadingSinceLastRun.isEmpty {
            
            #if os(macOS)
            if Settings.shared.openFinderAfterReceiving {
                log("[SaveFilesManager] Opening \(filesFinishedDownloadingSinceLastRun.count) file(s) in Finder.")
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

        log("[SaveFilesManager] Stopping access to security scoped resource: \(url)")
        url.stopAccessingSecurityScopedResource()
        securityScopeUrl = nil
    }

    
    public func getSaveDirectory() -> URL {
        
        // Not supported on iOS
        #if os(macOS)
        if let securityScopeUrl = securityScopeUrl {
            log("[SaveFilesManager] Using existing security scope URL: \(securityScopeUrl)")
            return securityScopeUrl
        }

        if let bookmarkData = Settings.shared.saveFolderBookmark {
            var isStale = false
   
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                if !isStale {
                    if url.startAccessingSecurityScopedResource() {
                        log("[SaveFilesManager] Successfully accessed security scoped resource: \(url)")

                        securityScopeUrl = url
                        return url
                    }
                } else {
                    log("[SaveFilesManager] Bookmark is stale, using default downloads folder.")
                }

            } catch {
                log("[SaveFilesManager] Failed to resolve bookmark: \(error), using default downloads folder.")
            }
        }

        do {
            return try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true).resolvingSymlinksInPath()
        } catch {
            fatalError("[SaveFilesManager] Failed to get downloads directory: \(error)")
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
}
