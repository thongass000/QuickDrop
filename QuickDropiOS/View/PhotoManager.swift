//
//  PhotoManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.11.25.
//

import UIKit
import Photos
import UniformTypeIdentifiers


struct PhotoManager {

    /// Returns if there are photos or videos among the given URLs.
    static func hasPhotosOrVideos(at urls: [URL]) -> Bool {
        urls.contains(where: { isImageFile(at: $0) || isVideoFile(at: $0) })
    }
    
    
    /// Saves any image/video URLs to the user's Photos library.
    /// - Parameters:
    ///   - urls: Remote or local URLs to inspect.
    ///   - openPhotosOnSuccess: If true, will try to open the Photos app after saving.
    /// - Throws: `SaveToPhotosError` or underlying URLSession/Photos errors.
    static func saveMediaToPhotoLibrary(from urls: [URL], openPhotosOnSuccess: Bool = true) async throws {
        
        let candidates = urls.filter { isImageFile(at: $0) || isVideoFile(at: $0) }
        guard !candidates.isEmpty else { throw SaveToPhotosError.noSavableContent }
        
        let authStatus = await requestAddOnlyPhotoAuthorization()
        guard authStatus == .authorized || authStatus == .limited else {
            throw SaveToPhotosError.permissionDenied
        }
        
        var imageItems: [ImageItem] = []
        var videoItems: [VideoItem] = []
        
        
        // Extract creation date for image and video
        for sourceURL in candidates {
            
            if isImageFile(at: sourceURL) {
                let exifDate = EXIFUtils.exifOriginalDate(from: sourceURL)
                imageItems.append(ImageItem(fileURL: sourceURL, creationDate: exifDate))
            } else {
                let videoDate = await getVideoCreationDate(from: sourceURL)
                videoItems.append(VideoItem(fileURL: sourceURL, creationDate: videoDate))
            }
        }
        
        guard !imageItems.isEmpty || !videoItems.isEmpty else {
            throw SaveToPhotosError.noSavableContent
        }
        
        
        // Import into Photos; explicitly set creationDate so it doesn't default to "now".
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                for item in imageItems {
                    if let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: item.fileURL) {
                        if let date = item.creationDate {
                            request.creationDate = date
                        }
                    }
                }
                
                for item in videoItems {
                    if let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: item.fileURL) {
                        if let date = item.creationDate {
                            request.creationDate = date
                        }
                    }
                }
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? SaveToPhotosError.saveFailed)
                }
            })
        }
        
        
        // Delete files in documents directory after successful import
        imageItems.forEach({ item in
            do { try FileManager.default.removeItem(at: item.fileURL) }
            catch { log("Failed to delete image at \(item.fileURL): \(error)") }
        })
        
        videoItems.forEach({ item in
            do { try FileManager.default.removeItem(at: item.fileURL) }
            catch { log("Failed to delete video at \(item.fileURL): \(error)") }
        })
        
        
        // Open the Photos app
        if openPhotosOnSuccess {
            if let url = URL(string: "photos-redirect://") {
                DispatchQueue.main.async  {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    
    private static func isImageFile(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard let type = UTType(filenameExtension: ext) else {
            return false
        }
        
        return type.conforms(to: .image)
    }
    
    
    private static func isVideoFile(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard let type = UTType(filenameExtension: ext) else {
            return false
        }
        // `.movie` is the canonical file-based video type; `.audiovisualContent`
        // catches some broader cases if needed.
        return type.conforms(to: .movie) || type.conforms(to: .audiovisualContent)
    }
    
    
    private static func getVideoCreationDate(from url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)
        
        do {
            // AVMetadataItem that typically contains an ISO‑8601 string
            guard let item = try await asset.load(.creationDate),
                  let dateString = try await item.load(.stringValue) else {
                return nil
            }
            
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        }
        catch {
            log("Failed to load creation date from \(url): \(error)")
            return nil
        }
    }
    
    
    /// Requests add-only Photos permission
    private static func requestAddOnlyPhotoAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    
    private enum SaveToPhotosError: Error, LocalizedError {
        case noSavableContent
        case permissionDenied
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .noSavableContent:
                return "SaveToPhotosErrorNoSavableContent".localized()
            case .permissionDenied:
                return "SaveToPhotosErrorPermissionDenied".localized()
            case .saveFailed:
                return "SaveToPhotosErrorSaveFailed".localized()
            }
        }
    }
    
    
    private struct ImageItem {
        let fileURL: URL
        let creationDate: Date?
    }
    
    
    private struct VideoItem {
        let fileURL: URL
        let creationDate: Date?
    }
}
