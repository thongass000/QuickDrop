//
//  AttachmentDetails.swift
//  QuickDrop
//
//  Created by Leon Böttger on 17.08.25.
//

import Foundation
import SwiftUI

struct AttachmentDetails {
    var urls: [URL]
    var textToSend: String?
    var shortDescription: String
    #if os(macOS)
    var previewImage: NSImage?
    #else
    var previewImage: Image?
    #endif
    
    var closeView: (() -> Void)? = nil
}
