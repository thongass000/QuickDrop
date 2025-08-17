//
//  Attachments.swift
//  QuickDrop
//
//  Created by Leon Böttger on 17.08.25.
//

import Foundation
import UniformTypeIdentifiers
import SwiftUI
#if os(macOS)
import Cocoa
#endif

func loadAttachments(with extensionContext: NSExtensionContext?, loadedItems: @escaping (AttachmentDetails) -> Void) {
    
    guard let extensionContext = extensionContext else { fatalError() }
    
    
    log("Loading attachments...")
    
    var result = AttachmentDetails(urls: [], textToSend: nil, shortDescription: "", previewImage: nil)
    
    let item = extensionContext.inputItems[0] as! NSExtensionItem
    
    if let attachments = item.attachments {
        if let text = item.attributedContentText?.string, attachments.isEmpty {
            result.textToSend = text
            
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
            
            loadedItems(result)
            
        } else {
            for attachment in attachments {
                
                    attachment.loadItem(forTypeIdentifier: attachment.registeredTypeIdentifiers.first!, options: nil) { data, _ in
                        
                        if let urlData = data as? Data,
                           let url = URL(dataRepresentation: urlData, relativeTo: nil, isAbsolute: false) {

                            log("Found URL from Data: \(url)")
                            result.urls += [url]
                        }
                        else if let url = data as? NSURL {
                            log("Found NSURL: \(url)")
                            result.urls += [(url as URL)]
                        }
                        else {
                            log("Attachment is not a URL, ignoring.")
                            let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
                            extensionContext.cancelRequest(withError: cancelError)
                        }
                        
                        if result.urls.count == attachments.count {
                            if result.urls.count == 1 {
                                
                                if result.urls[0].isFileURL {
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
            }
        }
    }
    else {
        log("No attachments found in extension context. Exiting.")
        
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        extensionContext.cancelRequest(withError: cancelError)
    }
}
