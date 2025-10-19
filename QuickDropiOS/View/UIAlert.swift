//
//  UIAlert.swift
//  QuickDrop
//
//  Created by Leon Böttger on 17.08.25.
//

import SwiftUI
import UIKit

// MARK: - UIKit Alert Presenter

final class ProgressAlert {
    static let shared = ProgressAlert()
    private init() {}

    private weak var progressAlert: UIAlertController?
    private weak var progressView: UIProgressView?

    // MARK: - Initial Accept / Decline
    func askForUserPermission(title: String, message: String, acceptLabel: String, acceptAlwaysLabel: String?, rejectLabel: String, acceptAutomatically: Bool, onAccept: @escaping (AcceptAction) -> Void, onCancel: @escaping () -> Void) {
        guard let vc = topMostViewController() else { return }

        if acceptAutomatically {
            onAccept(.Accept)
            self.showProgressAlert(on: vc, onCancel: onCancel)
        }
        else {
            
            let alert = UIAlertController(title: title,
                                          message: message,
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: rejectLabel, style: .cancel, handler: { _ in
                onAccept(.Decline)
            }))
            
            alert.addAction(UIAlertAction(title: acceptLabel, style: .default, handler: { _ in
                onAccept(.Accept)
                self.showProgressAlert(on: vc, onCancel: onCancel)
            }))
            
            if let acceptAlways = acceptAlwaysLabel {
                alert.addAction(UIAlertAction(title: acceptAlways, style: .default, handler: { _ in
                    onAccept(.AcceptAlways)
                    self.showProgressAlert(on: vc, onCancel: onCancel)
                }))
            }
            
            vc.present(alert, animated: true)
        }
    }

    // MARK: - Progress Alert
    private func showProgressAlert(on vc: UIViewController, onCancel: @escaping () -> Void) {
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
    func updateProgress(_ progress: Double?, completion: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            if let p = progress {
                self.progressView?.setProgress(Float(p), animated: true)
                completion()
            } else {
                // Completed: dismiss progress and show final alert
                self.progressAlert?.dismiss(animated: true) {
                    completion()
                }
                self.progressAlert = nil
                self.progressView = nil
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
