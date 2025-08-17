//
//  Zip.swift
//  QuickDrop
//
//  Created by Leon Böttger on 11.03.25.
//

import Foundation

class Zip {
 
    static func createAtTemporaryDirectory(zipFilename: String, zipExtension: String = "zip", fromDirectory directoryURL: URL) throws -> URL {
       
        let finalURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(zipFilename)
            .appendingPathExtension(zipExtension)
        
        return try createAt(
            zipFinalURL: finalURL,
            fromDirectory: directoryURL
        )
    }

    
    static func createAt(zipFinalURL: URL, fromDirectory directoryURL: URL) throws -> URL {
        
        guard directoryURL.isDirectory else {
            throw CreateZipError.urlNotADirectory(directoryURL)
        }
        
        var fileManagerError: Swift.Error?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        
        coordinator.coordinate(readingItemAt: directoryURL, options: .forUploading, error: &coordinatorError) { zipCreatedURL in
            do {
                // clean if file exists
                if FileManager.default.fileExists(atPath: zipFinalURL.path) {
                    try FileManager.default.removeItem(at: zipFinalURL)
                }

                try FileManager.default.moveItem(at: zipCreatedURL, to: zipFinalURL)
                
            } catch {
                fileManagerError = error
            }
        }
        
        if let error = coordinatorError ?? fileManagerError {
            throw CreateZipError.failedToCreateZIP(error)
        }
        
        return zipFinalURL
    }
    
    
    enum CreateZipError: Swift.Error {
        case urlNotADirectory(URL)
        case failedToCreateZIP(Swift.Error)
    }
}


extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
