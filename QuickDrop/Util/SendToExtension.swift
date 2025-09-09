//
//  SendToExtension.swift
//  QuickDrop
//
//  Created by Leon Böttger on 09.09.25.
//

import Foundation
import AppKit

func sendToSharingService(items: [Any]) {
    if let sharingService = NSSharingService(named: NSSharingService.Name("com.leonboettger.neardrop.ShareExtension")) {
        sharingService.perform(withItems: items)
    }
    else {
        DispatchQueue.main.async {
            // show alert
            AudioManager.playErrorSound()
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "ShareExtensionDisabledTitle".localized()
            alert.informativeText = "ShareExtensionDisabledDescription".localized()
            alert.addButton(withTitle: "CloseAlert".localized())
            alert.runModal()
        }
    }
}
