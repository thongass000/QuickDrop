//
//  ReceiveModel.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.08.25.
//

import SwiftUI
import StoreKit
import UserNotifications

#if os(macOS)
import BezelNotification
#else
import LUI
#endif

class ReceiveModel: ObservableObject, InboundAppDelegate {
    
    let controlPlusScreen: (Bool) -> Void
    
    init(controlPlusScreen: @escaping (Bool) -> Void = { _ in }) {
        self.controlPlusScreen = controlPlusScreen
        NearbyConnectionManager.shared.mainAppDelegate = self
        NearbyConnectionManager.shared.becomeVisible()
    }
    
    
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
        
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        AudioManager.playIncomingFileSound()
        #endif

        let acceptAutomatically = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticallyAcceptFiles.rawValue)

        let fileStr: String

        if let textTitle = transfer.textDescription {
            fileStr = textTitle
        } else if transfer.files.count == 1 {
            fileStr = transfer.files[0].name
        } else {
            fileStr = String.localizedStringWithFormat("NFiles".localized(), transfer.files.count)
        }

        
        let mainMessage: String
        let name = device.name ?? "Android"
        
        switch transfer.type {
            case .file:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingFiles" : "DeviceSendingFiles").localized(), arguments: [name, fileStr])
            
            case .text:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingText" : "DeviceSendingText").localized(), arguments: [name, fileStr])
            
            case .url:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingUrl" : "DeviceSendingUrl").localized(), arguments: [name, fileStr])
        }
        
       
        let pinCodeMessage = String(format: "PinCode".localized(), arguments: [transfer.pinCode ?? "?"])
        let transferID = transfer.id

        if acceptAutomatically {
            pressAcceptButton(transferID: transfer.id)

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    log("[ReceiveModel] User granted notification permissions")

                    let notificationContent = UNMutableNotificationContent()
                    notificationContent.title = "QuickDrop"
                    notificationContent.body = mainMessage
                    notificationContent.sound = nil
                    let notificationId = UUID().uuidString

                    let notificationReq = UNNotificationRequest(identifier: notificationId, content: notificationContent, trigger: nil)
                    UNUserNotificationCenter.current().add(notificationReq)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
                    }
                }
            }
        } else {
            
            let title = "QuickDrop - \(pinCodeMessage)"
            let primaryButtonTitle = "Accept".localized()
            let primaryButtonAction = { self.pressAcceptButton(transferID: transferID) }
            let secondaryButtonTitle = "Decline".localized()
            let secondaryButtonAction = { NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: false, storeInTemp: false) }
            
            #if os(macOS)
            let alert = NSAlert()
            alert.alertStyle = .informational

            alert.messageText = title
            alert.informativeText = mainMessage
            alert.addButton(withTitle: primaryButtonTitle)
            alert.addButton(withTitle: secondaryButtonTitle)

            let result = alert.runModal()

            if result == .alertFirstButtonReturn {
                primaryButtonAction()
            } else if result == .alertSecondButtonReturn {
                secondaryButtonAction()
            }
            #else
            // iOS
            ProgressAlert.shared.askForUserPermission(title: title, message: mainMessage, acceptLabel: primaryButtonTitle, rejectLabel: secondaryButtonTitle) { accepted in
                accepted ? primaryButtonAction() : secondaryButtonAction()
            }
            #endif
        }
    }
    
    
    func transferProgress(progress: Double) {
        #if os(iOS)
        ProgressAlert.shared.updateProgress(progress)
        #endif
    }
    
    
    func connectionWasTerminated(from device: RemoteDeviceInfo, wasPlainTextTransfer: Bool, error: (any Error)?) {
        
        #if os(macOS)
        finish()
        #else
        ProgressAlert.shared.updateProgress(nil) {
            finish()
        }
        #endif
        
        func finish() {
            if let error = error {
                controlPlusScreen(false)
                ErrorAlertHandler.shared.showErrorAlert(for: device.name ?? "Android", error: error)
            } else {
                
                if wasPlainTextTransfer {
                    showCopiedToClipboardAlert()
                }
                
                let currentCount = incomingTransmissionCount()
                if currentCount == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        SKStoreReviewController.requestReview()
                    }
                }

                UserDefaults.standard.set(currentCount + 1, forKey: UserDefaultsKeys.transmissionCount.rawValue)
                log("[ReceiveModel] Successful transmission. Current count: \(currentCount)")
            }
        }
    }
    
    
    private func showCopiedToClipboardAlert() {
        #if os(macOS)
        DispatchQueue.main.async {
            BezelNotification.show(messageText: "InsertedIntoClipboard".localized(), icon: .clipboard)
        }
        #else
        // iOS
        doubleVibration()
        #endif
    }
    
    
    private func pressAcceptButton(transferID: String) {
        if isFileTransferRestricted() {
            log("[ReceiveModel] Showing plus screen...")
            NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: true, storeInTemp: true)
            controlPlusScreen(true)
        } else {
            NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: true, storeInTemp: false)
        }
    }
}
