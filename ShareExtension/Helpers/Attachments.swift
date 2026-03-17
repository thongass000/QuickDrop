//
//  Attachments.swift
//  QuickDrop
//
//  Created by Leon Böttger on 17.08.25.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
import LUI
#if os(macOS)
import Cocoa
#elseif canImport(UIKit)
import UIKit
#endif

func loadAttachments(with extensionContext: NSExtensionContext?, loadedItems: @escaping (AttachmentDetails) -> Void) {
    
    guard let extensionContext = extensionContext else { fatalError() }
    
    log("Loading attachments...")
    
    var result = AttachmentDetails(urls: [], textToSend: nil, shortDescription: "", previewImage: nil)
    var ignoredAttachments = 0
    
    let item = extensionContext.inputItems[0] as! NSExtensionItem
    
    if let attachments = item.attachments {
        
        if !attachments.isEmpty {
            for attachment in attachments {
                
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                        if let urlData = data as? Data,
                           let url = URL(dataRepresentation: urlData, relativeTo: nil, isAbsolute: false) {
                            result.urls += [(url as URL)]
                        } else if let url = data as? NSURL {
                            result.urls += [(url as URL)]
                        }
                        else {
                            log("Attachment is not a URL, ignoring. All attachments: \(attachments.description)")
                            ignoredAttachments += 1
                        }
                        
                        checkIfAttachmentsLoaded(result: result,
                                                 attachmentCount: attachments.count,
                                                 ignoredAttachments: ignoredAttachments,
                                                 item: item,
                                                 loadedItems: loadedItems)
                    }
                }
                else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    let imageTypeIdentifier = attachment.registeredTypeIdentifiers.first(where: {
                        UTType($0)?.conforms(to: .image) == true
                    }) ?? UTType.image.identifier
                    attachment.loadItem(forTypeIdentifier: imageTypeIdentifier, options: nil) { data, _ in
                        if let url = imageUrl(from: data, typeIdentifier: imageTypeIdentifier) {
                            result.urls += [url]
                        }
                        else {
                            log("Attachment is not an image URL or data, ignoring. All attachments: \(attachments.description)")
                            ignoredAttachments += 1
                        }
                        
                        checkIfAttachmentsLoaded(result: result,
                                                 attachmentCount: attachments.count,
                                                 ignoredAttachments: ignoredAttachments,
                                                 item: item,
                                                 loadedItems: loadedItems)
                    }
                }
                else {
                    attachment.loadItem(forTypeIdentifier: attachment.registeredTypeIdentifiers.first!, options: nil) { data, _ in
                        
                        if let url = data as? NSURL {
                            log("Found NSURL: \(url)")
                            result.urls += [(url as URL)]
                            
                            checkIfAttachmentsLoaded(result: result,
                                                     attachmentCount: attachments.count,
                                                     ignoredAttachments: ignoredAttachments,
                                                     item: item,
                                                     loadedItems: loadedItems)
                        }
                        else {
                            log("Attachment is not a URL, ignoring. All attachments: \(attachments.description)")
                            ignoredAttachments += 1
                            
                            checkIfAttachmentsLoaded(result: result,
                                                     attachmentCount: attachments.count,
                                                     ignoredAttachments: ignoredAttachments,
                                                     item: item,
                                                     loadedItems: loadedItems)
                        }
                    }
                }
            }
        }
        else {
            deliverTextIfPossible(from: item, loadedItems: loadedItems)
        }
    }
    else {
        log("No attachments found in extension context. Exiting.")
        
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        extensionContext.cancelRequest(withError: cancelError)
    }
}


private func deliverTextIfPossible(from item: NSExtensionItem, loadedItems: @escaping (AttachmentDetails) -> Void) {
    guard let details = textAttachmentDetails(from: item) else { return }
    DispatchQueue.main.async {
        loadedItems(details)
    }
}


private func textAttachmentDetails(from item: NSExtensionItem) -> AttachmentDetails? {
    guard let text = item.attributedContentText?.string else { return nil }
    
    log("Found text content: \(text)")
    
    var result = AttachmentDetails(urls: [], textToSend: text, shortDescription: "", previewImage: nil)
    
    #if os(macOS)
    result.previewImage = NSImage(named: NSImage.multipleDocumentsName)
    #else
    result.previewImage = Image(systemName: "text.document")
    #endif
    
    let maxLength = 50
    let cleanedText = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
    
    if cleanedText.count > maxLength {
        let index = cleanedText.index(cleanedText.startIndex, offsetBy: maxLength)
        result.shortDescription = String(cleanedText[..<index]) + "..."
    } else {
        result.shortDescription = cleanedText
    }
    
    return result
}


private func checkIfAttachmentsLoaded(result: AttachmentDetails,
                                      attachmentCount: Int,
                                      ignoredAttachments: Int = 0,
                                      item: NSExtensionItem,
                                      loadedItems: @escaping (AttachmentDetails) -> Void) {
    
    var result = result
    
    if result.urls.count == attachmentCount-ignoredAttachments {
        
        // Unable to load anything useful, check if there is text as last resort
        if result.urls.count == 0 {
            deliverTextIfPossible(from: item, loadedItems: loadedItems)
            return
        }
        else if result.urls.count == 1 {
            
            if result.urls[0].isFileURL {
                
                log("Single file URL found: \(result.urls[0])")
                
                result.shortDescription = result.urls[0].lastPathComponent
                #if os(macOS)
                result.previewImage = NSWorkspace.shared.icon(forFile: result.urls[0].path)
                #else
                result.previewImage = Image(systemName: "document")
                #endif
            }
            else if result.urls[0].scheme == "http" || result.urls[0].scheme == "https" {
                result.shortDescription = result.urls[0].absoluteString
                #if os(macOS)
                result.previewImage = NSImage(named: NSImage.networkName)
                #else
                result.previewImage = Image(systemName: "network")
                #endif
            }
        }
        else {
            result.shortDescription = String.localizedStringWithFormat("NFiles".localized(), result.urls.count)
            #if os(macOS)
            result.previewImage = NSImage(named: NSImage.multipleDocumentsName)
            #else
            result.previewImage = Image(systemName: "document")
            #endif
        }
        
        DispatchQueue.main.async {
            loadedItems(result)
        }
    }
}


private func imageUrl(from data: Any?, typeIdentifier: String) -> URL? {
    if let url = data as? NSURL {
        log("Found image URL: \(url)")
        return url as URL
    }
    
    if let data = data as? Data {
        let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "png"
        return writeDataToTemporaryFile(data: data, fileExtension: fileExtension)
    }
    
    #if canImport(UIKit)
    if let image = data as? UIImage,
       let imageData = image.pngData() {
        return writeDataToTemporaryFile(data: imageData, fileExtension: "png")
    }
    #elseif os(macOS)
    if let image = data as? NSImage,
       let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let pngData = rep.representation(using: .png, properties: [:]) {
        return writeDataToTemporaryFile(data: pngData, fileExtension: "png")
    }
    #endif
    
    return nil
}


private func writeDataToTemporaryFile(data: Data, fileExtension: String) -> URL? {
    let sanitizedExtension = fileExtension.isEmpty ? "dat" : fileExtension
    let tempUrl = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).\(sanitizedExtension)")
    do {
        try data.write(to: tempUrl)
        return tempUrl
    }
    catch {
        log("Failed to write attachment data to temp file: \(error)")
        return nil
    }
}
