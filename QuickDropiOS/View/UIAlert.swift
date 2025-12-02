//
//  UIAlert.swift
//  QuickDrop
//
//  Created by Leon Böttger on 17.08.25.
//

import SwiftUI
import UIKit
import LUI

// MARK: - UIKit Alert Presenter

final class ProgressAlert {
    static let shared = ProgressAlert()
    private init() {}

    private weak var progressAlert: UIAlertController?
    private weak var progressView: UIProgressView?

    // MARK: - Initial Accept / Decline
    func askForUserPermission(title: String, message: String, acceptLabel: String, acceptAlwaysLabel: String?, rejectLabel: String, onAccept: @escaping (AcceptAction) -> Void) {
        guard let vc = topMostViewController() else { return }

        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: rejectLabel, style: .cancel, handler: { _ in
            onAccept(.Decline)
        }))
        
        alert.addAction(UIAlertAction(title: acceptLabel, style: .default, handler: { _ in
            onAccept(.Accept)
        }))
        
        if let acceptAlways = acceptAlwaysLabel {
            alert.addAction(UIAlertAction(title: acceptAlways, style: .default, handler: { _ in
                onAccept(.AcceptAlways)
            }))
        }
        
        vc.present(alert, animated: true)
    }
    
    
    func presentIncomingTransferDoneAlert(
        title: String,
        message: String,
        onImportToPhotos: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil
    ) {
        guard let vc = topMostViewController() else { return }

        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        // "Show in Files"
        alert.addAction(UIAlertAction(title: "OpenInFiles".localized(), style: .default) { _ in
            FileManager.default.openDocumentFolder()
        })

        // Optional "Import to Photos"
        if let importHandler = onImportToPhotos {
            alert.addAction(UIAlertAction(title: "ImportToPhotos".localized(), style: .default) { _ in
                importHandler()
            })
        }

        // "Done"
        alert.addAction(UIAlertAction(title: "Done".localized(), style: .cancel) { _ in
            onDone?()
        })

        vc.present(alert, animated: true)
    }

    

    // MARK: - Progress Alert
    private func showProgressAlert(onCancel: @escaping () -> Void) {
        
        guard let vc = topMostViewController() else { return }
        
        let alert = UIAlertController(title: "Receiving".localized(),
                                      message: "\n\n",
                                      preferredStyle: .alert)

        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(pv)
        NSLayoutConstraint.activate([
            pv.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            pv.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
            pv.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor, constant: 8)
        ])

        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: { _ in
            log("Cancel during progress")
            onCancel()
        })
        alert.addAction(cancel)

        self.progressAlert = alert
        self.progressView = pv

        vc.present(alert, animated: true)
    }
    

    // MARK: - Update Progress
    // progress: 0…1 → update progress, nil → finished
    func updateProgress(_ progress: Double?, onCancel: @escaping () -> Void, completion: @escaping () -> Void) {
        
        // No progress to show, nothing shown currently → just complete
        if progressAlert == nil && progress == nil {
            completion()
            return
        }
        
        DispatchQueue.main.async {
            
            if let p = progress {
                // Show progress if not shown yet
                if self.progressAlert == nil {
                    self.showProgressAlert(onCancel: onCancel)
                }
                
                self.progressView?.setProgress(Float(p), animated: true)
                completion()
            }
            else {
                // Completed: dismiss progress and show final alert
                self.progressAlert?.dismiss(animated: true) {
                    completion()
                    self.progressAlert = nil
                    self.progressView = nil
                }
            }
        }
    }
    

    // MARK: - Helpers
    private func topMostViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first) -> UIViewController? {
        if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topMostViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
        return base
    }
    
    
    enum AcceptAction {
        case Accept
        case AcceptAlways
        case Decline
    }
}
