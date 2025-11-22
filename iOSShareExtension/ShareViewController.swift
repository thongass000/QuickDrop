//
//  ShareViewController.swift
//  iOSShareExtension
//
//  Created by Leon Böttger on 17.08.25.
//

import UIKit
import SwiftUI
import LUI

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NearbyConnectionManager.shared.stopDeviceDiscovery()
        
        loadAttachments(with: extensionContext, loadedItems: { [self] result in
            
            log("[ShareViewController] Loaded attachments: \(result)")
            
            var attachmentDetails = result
            attachmentDetails.closeView = { [weak self] in
                // Close the extension view
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
            
            DispatchQueue.main.async {
                NearbyConnectionManager.shared.attachments = attachmentDetails
            }
        })
        
        // skip introduction for share extension
        LUIInit(configuration: configuration)
        LUISettings.sharedInstance.appLaunchedBefore = true
 
        let hostingController = UIHostingController(rootView: ContentView())

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
    
    
    override func viewDidDisappear(_ animated: Bool) {
        NearbyConnectionManager.shared.stopDeviceDiscovery()
        
        super.viewDidDisappear(animated)
        log("[ShareViewController] Disappeared view.")
    }
}
