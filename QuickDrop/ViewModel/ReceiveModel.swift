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
    
    
    /// For each connection ID, store the last reported progress value
    private var processes: [String: Double] = [:]
    
    #if os(macOS)
    @Published var progress: Double? = nil
    private var toastWindow: NSWindow?
    private var toastHosting: NSHostingView<QuickDropToastView>?
    #endif
    
    let controlPlusScreen: (Bool) -> Void
    
    init(controlPlusScreen: @escaping (Bool) -> Void = { _ in }) {
        self.controlPlusScreen = controlPlusScreen
        NearbyConnectionManager.shared.addInboundAppDelegate(self)
        NearbyConnectionManager.shared.becomeVisible()
    }
    
    
    deinit {
        NearbyConnectionManager.shared.removeInboundAppDelegate(self)
    }
    
    
    func obtainUserConsent(transfer: TransferMetadata, device: RemoteDeviceInfo) {
        
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        AudioManager.playIncomingFileSound()
        #endif

        let mainMessage = transfer.getDescription(deviceName: device.name ?? "Android", alreadyAccepted: false)
        let pinCodeMessage = transfer.getPinCodeMessage()
        let transferID = transfer.id
        
        let title = "QuickDrop - \(pinCodeMessage)"
        let primaryButtonTitle = "Accept".localized()
        let primaryButtonAction = { (trustDevice: Bool) in
            NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: true, trustDevice: trustDevice)
            
            #if os(macOS)
            if transfer.type == .text {
                DispatchQueue.main.async {
                    BezelNotification.show(messageText: "InsertedIntoClipboard".localized(), icon: .clipboard)
                }
            }
            #endif
        }
        
        let secondaryButtonTitle = "Decline".localized()
        let secondaryButtonAction = { NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: false, trustDevice: false) }
        
        #if os(macOS)
        let alert = NSAlert()
        alert.alertStyle = .informational

        alert.messageText = title
        alert.informativeText = mainMessage
        alert.addButton(withTitle: primaryButtonTitle)
        alert.addButton(withTitle: secondaryButtonTitle)
        
        if transfer.allowsToBeAddedAsTrustedDevice {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "AutoAcceptFromThisDevice".localized()
        }

        let result = alert.runModal()

        if result == .alertFirstButtonReturn {
            primaryButtonAction(alert.suppressionButton?.state == .on)
        } else if result == .alertSecondButtonReturn {
            secondaryButtonAction()
        }
        #else
        // iOS
        let alwaysAcceptLabel = transfer.allowsToBeAddedAsTrustedDevice ? "AlwaysAccept".localized() : nil
        ProgressAlert.shared.askForUserPermission(title: title, message: mainMessage, acceptLabel: primaryButtonTitle, acceptAlwaysLabel: alwaysAcceptLabel, rejectLabel: secondaryButtonTitle) { accepted in
            
            switch accepted {
                case .Accept:
                    primaryButtonAction(false)
                case .AcceptAlways:
                    primaryButtonAction(true)
                case .Decline:
                    secondaryButtonAction()
            }
        } onCancel: {
            NearbyConnectionManager.shared.cancelTransfer(id: transferID)
        }
        #endif
    }
    
    
    func obtainedUserConsentAutomatically(transfer: TransferMetadata, device: RemoteDeviceInfo) {
        
        let mainMessage = transfer.getDescription(deviceName: device.name ?? "Android", alreadyAccepted: true)
        
        #if os(macOS)
        
        NSApp.activate(ignoringOtherApps: true)
        AudioManager.playIncomingFileSound()
        
        // If file -> no notification, as there is the QuickDrop progress toast
        if transfer.type != .file {
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
        }
        #else
        // If text is received, nothing is shown, as it is directly inserted into clipboard automatically
        // Therefore, give a feedback dialog in this case
        if transfer.type == .text {
            showAlert(title: "QuickDrop", message: mainMessage)
        }
        else {
            ProgressAlert.shared.showProgressAlert(onCancel: {
                NearbyConnectionManager.shared.cancelTransfer(id: transfer.id)
            })
        }
        #endif
    }
    
    
    func transferProgress(connectionID: String, progress: Double) {
        
        // Update process dictionary
        processes[connectionID] = progress
        
        // Calcualate average value for all ongoing transfers
        let totalProgress = processes.values.reduce(0, +)
        let averageProgress = totalProgress / Double(processes.count)
        
        #if os(iOS)
        ProgressAlert.shared.updateProgress(averageProgress)
        #else
        DispatchQueue.main.async {
            self.progress = averageProgress
            self.showQuickDropToast(for: connectionID)
        }
        #endif
    }
    
    
    func connectionWasTerminated(connectionID: String, from device: RemoteDeviceInfo, wasPlainTextTransfer: Bool, error: (any Error)?) {
        
        processes.removeValue(forKey: connectionID)
        
        #if os(macOS)
        DispatchQueue.main.async {
            self.hideQuickDropToast()
            
            if self.processes.isEmpty {
                self.progress = nil
            }
        }
        finish()
        #else
        if self.processes.isEmpty {
            ProgressAlert.shared.updateProgress(nil) {
                finish()
            }
        }
        #endif
        
        func finish() {
            if let error = error {
                
                #if os(iOS)
                errorVibration()
                #endif
                
                controlPlusScreen(false)
                ErrorAlertHandler.shared.showErrorAlert(for: device.name ?? "Android", error: error)
            } else {
                
                #if os(iOS)
                doubleVibration()
                #endif
                
                let currentCount = Settings.shared.incomingTransmissionCount
                
                #if os(macOS)
                // If distributed directly, do not request review here as it does not work
                if currentCount == 0 && !DistributionDetector.isDirectDistributionEnabled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        SKStoreReviewController.requestReview()
                    }
                }
                #endif

                Settings.shared.incomingTransmissionCount = currentCount + 1
                log("[ReceiveModel] Successful transmission. Current count: \(currentCount)")
            }
        }
    }
    
    
    func showPlusScreen() {
        DispatchQueue.main.async {
            self.controlPlusScreen(true)
        }
    }
    
    
    // MARK: - macOS Progress Overlay
    
    #if os(macOS)
    func showQuickDropToast(for connectionID: String) {
        guard toastWindow == nil else { return }

        let contentView = QuickDropToastView(
            receiveModel: self,
            onCancel: {
                NearbyConnectionManager.shared.cancelTransfer(id: connectionID)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame.size = toastViewSize

        // Prefer the screen under the mouse, then the key window’s screen, then main
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSApp.keyWindow?.screen
            ?? NSScreen.main

        guard let screen else { return }

        let frame = screen.frame
        let visible = screen.visibleFrame

        let marginX: CGFloat = 24
        let marginFromTop: CGFloat = 30

        // If the menu bar is auto-hidden, visible.maxY == frame.maxY; subtract the status bar thickness to stay clear
        let menuBarHidden = abs(frame.maxY - visible.maxY) < 0.5
        let extraTopInset = menuBarHidden ? NSStatusBar.system.thickness : 0

        let targetX = visible.maxX - toastViewSize.width - marginX
        let targetY = visible.maxY - toastViewSize.height - marginFromTop - extraTopInset

        // Start slightly above the final spot for a smooth slide-in
        let startY = min(frame.maxY + 10, targetY + 10)
        let startFrame = CGRect(x: targetX, y: startY, width: toastViewSize.width, height: toastViewSize.height)

        let window = NSWindow(contentRect: startFrame,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = hostingView
        window.ignoresMouseEvents = false
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        self.toastWindow = window
        self.toastHosting = hostingView

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(CGPoint(x: targetX, y: targetY))
            window.animator().alphaValue = 1
        }
    }


    func hideQuickDropToast() {
        guard let window = toastWindow,
              let screen = NSScreen.main else { return }

        let offscreenY = screen.visibleFrame.origin.y + screen.visibleFrame.height + 20

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(CGPoint(x: window.frame.origin.x, y: offscreenY))
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.toastWindow = nil
            self.toastHosting = nil
        })
    }
    #endif
}
