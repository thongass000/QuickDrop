//
//  ShareViewController.swift
//  iOSShareExtension
//
//  Created by Leon Böttger on 17.08.25.
//

import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadAttachments(with: extensionContext, loadedItems: { [self] result in
            
            log("ShareViewController: Loaded attachments: \(result)")
            
            var attachmentDetails = result
            attachmentDetails.closeView = { [weak self] in
                // Close the extension view
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
            
            DispatchQueue.main.async {
                NearbyConnectionManager.shared.attachments = attachmentDetails
            }
        })
        
        // Replace with your app’s SwiftUI entry view
        let contentView = ContentView()

        // Embed SwiftUI inside the extension’s controller
        let hostingController = UIHostingController(rootView: contentView)

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        // Pin to edges
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}

