//
//  PhotoManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.11.25.
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

import LUI
import Photos
import UniformTypeIdentifiers

struct PhotoManager {

    /// Returns if there are photos or videos among the given URLs.
    static func hasPhotosOrVideos(at urls: [URL]) -> Bool {
        urls.contains(where: { EXIFUtils.isImageFile(at: $0) || EXIFUtils.isVideoFile(at: $0) })
    }
    
    
    /// Saves any image/video URLs to the user's Photos library.
    /// - Parameters:
    ///   - urls: Remote or local URLs to inspect.
    ///   - openPhotosOnSuccess: If true, will try to open the Photos app after saving.
    /// - Throws: `SaveToPhotosError` or underlying URLSession/Photos errors.
    static func saveMediaToPhotoLibrary(from urls: [URL], openPhotosOnSuccess: Bool = true) async throws {
        
        let authStatus = await requestAddOnlyPhotoAuthorization()
        guard authStatus == .authorized || authStatus == .limited else {
            throw SaveToPhotosError.permissionDenied
        }
        
        var imageItems: [ImageItem] = []
        var videoItems: [VideoItem] = []
        
        // Extract creation date for image and video
        for sourceURL in urls {
            let (type, date) = EXIFUtils.originalDate(from: sourceURL)
            
            if type == .image {
                imageItems.append(ImageItem(fileURL: sourceURL, creationDate: date))
            }
            if type == .video {
                videoItems.append(VideoItem(fileURL: sourceURL, creationDate: date))
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
            DispatchQueue.main.async  {
                #if os(iOS)
                if let url = URL(string: "photos-redirect://") {
                    UIApplication.shared.open(url)
                }
                #else
                if let url = URL(string: "photos-navigation://album?name=recently-saved") {
                    NSWorkspace.shared.open(url)
                }
                #endif
            }
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
}


// MARK: - Private types

private extension PhotoManager {
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
