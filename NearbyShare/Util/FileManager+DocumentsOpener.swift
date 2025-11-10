//
//  FileManager+DocumentsOpener.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.11.25.
//

import Foundation
import UIKit
import LUI

extension FileManager {
    public func openDocumentFolder() {
        #if !EXTENSION
        let documentsUrl = self.urls(for: .documentDirectory, in: .userDomainMask).first

        if let documentsUrl = documentsUrl, let sharedUrl = URL(string: "shareddocuments://\(documentsUrl.path)"), UIApplication.shared.canOpenURL(sharedUrl) {
            UIApplication.shared.open(sharedUrl, options: [:])
        }
        else {
            showAlert(title: "CouldNotOpenDocumentsFolder", message: "CouldNotOpenDocumentsFolderDescription")
        }
        #endif
    }
}
