//
//  AppDelegate.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

import Cocoa
import UserNotifications
import NearbyShare
import SwiftUI
import StoreKit

@main
class AppDelegate: NSObject, NSApplicationDelegate, MainAppDelegate{
    private var statusItem:NSStatusItem?
    private var activeIncomingTransfers:[String:TransferInfo]=[:]
    
    var welcomeWindow: NSWindow?
    var plusWindow: NSWindow?
    private var iapManager: IAPManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let menu=NSMenu()
        menu.addItem(withTitle: NSLocalizedString("VisibleToEveryone", value: "Visible to everyone", comment: ""), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: String(format: NSLocalizedString("DeviceName", value: "Device name: %@", comment: ""), arguments: [Host.current().localizedName!]), action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        
//        // Add "Recommended Apps" menu item
//        let recommendedAppsItem = NSMenuItem(title: NSLocalizedString("RecommendedApps", value: "Recommended Apps", comment: ""), action: #selector(openRecommendedApps), keyEquivalent: "")
//        menu.addItem(recommendedAppsItem)
        
        // Add "Privacy Policy" menu item
        let privacyPolicyItem = NSMenuItem(title: NSLocalizedString("PrivacyPolicy", value: "Privacy Policy", comment: ""), action: #selector(openPrivacyPolicy), keyEquivalent: "")
        menu.addItem(privacyPolicyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let userManualItem = NSMenuItem(title: NSLocalizedString("UserManual", value: "User Manual", comment: ""), action: #selector(openWelcomeScreen), keyEquivalent: "")
        menu.addItem(userManualItem)
        
        menu.addItem(withTitle: NSLocalizedString("Quit", value: "Quit QuickDrop", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        
        
        statusItem=NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image=NSImage(named: "MenuBarIcon")
        statusItem?.menu=menu
        statusItem?.behavior = .removalAllowed
        
        NearbyConnectionManager.shared.mainAppDelegate=self
        NearbyConnectionManager.shared.becomeVisible()
        
        iapManager = IAPManager.sharedInstance
        iapManager?.startObserving()
        
        // app did not lauch before
        if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.appLaunchedBefore.rawValue){
            
            log("Opening welcome screen")
            // open welcome screen
            openWelcomeScreen()
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.appLaunchedBefore.rawValue)
            
            // user installed the app after the IAP was implemented, set the user as eligible for IAP
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isEligibleForIap.rawValue)
        }
        else {
            // app launched before
            
            // user installed the app before the IAP was implemented, grant the plus version
            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.isEligibleForIap.rawValue) {
                log("Granting plus version for old user")
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.plusVersion.rawValue)
            }
            else {
                if !isPlusVersion() {
                    log("New user - plus version cannot be granted")
                }
            }
        }
    }
    
    
    @objc func openWelcomeScreen() {
        // Create the welcome screen SwiftUI view
        let welcomeView = WelcomeScreen {
            self.openPlusScreen(continueTransfer: {})
        }
        
        // Create an NSWindow to host the SwiftUI view
        welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        welcomeWindow?.center()
        welcomeWindow?.isReleasedWhenClosed = false
        welcomeWindow?.setFrameAutosaveName("WelcomeScreen")
        welcomeWindow?.contentView = NSHostingView(rootView: welcomeView)
        
        welcomeWindow?.isOpaque = false
        welcomeWindow?.backgroundColor = .clear
        
        // Ensure the window is always on top
        NSApp.activate(ignoringOtherApps: true) // Brings the whole app to the front
        welcomeWindow?.makeKeyAndOrderFront(nil)
        welcomeWindow?.level = .normal
    }
    
    
    @objc func openPlusScreen(continueTransfer: @escaping () -> Void) {
        // Create the welcome screen SwiftUI view
        let plusView = GetPlusView(closeView: {
            self.plusWindow?.close()
            continueTransfer()
        })
        
        // Create an NSWindow to host the SwiftUI view
        plusWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        plusWindow?.center()
        plusWindow?.isReleasedWhenClosed = false
        plusWindow?.setFrameAutosaveName("PlusScreen")
        plusWindow?.contentView = NSHostingView(rootView: plusView)
        
        // Ensure the window is always on top
        NSApp.activate(ignoringOtherApps: true) // Brings the whole app to the front
        plusWindow?.makeKeyAndOrderFront(nil)
        plusWindow?.level = .normal
    }
    
    
    func isPlusVersion() -> Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.plusVersion.rawValue)
    }
    
    func transmissionCount() -> Int {
        return UserDefaults.standard.integer(forKey: UserDefaultsKeys.transmissionCount.rawValue)
    }
    
    
    // Action for "Recommended Apps" menu item
    @objc func openRecommendedApps() {
        if let url = URL(string: "https://apps.apple.com/de/developer/leon-boettger/id1537384790") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Action for "Privacy Policy" menu item
    @objc func openPrivacyPolicy() {
        if let url = URL(string: "  ") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.isVisible=true
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        iapManager?.stopObserving()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    public func continueTransmission(accept: Bool, transferID: String) {
        NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: accept)
        
        if !accept {
            activeIncomingTransfers.removeValue(forKey: transferID)
        }
    }
    
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
        self.activeIncomingTransfers[transfer.id] = TransferInfo(device: device, transfer: transfer)
        
        NSSound(named: NSSound.Name("NSUserNotificationDefaultSoundName"))?.play()
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        
        let fileStr: String
        
        if let textTitle = transfer.textDescription{
            fileStr = textTitle
        } else if transfer.files.count == 1 {
            fileStr = transfer.files[0].name
        } else {
            fileStr = String.localizedStringWithFormat(NSLocalizedString("NFiles", value: "%d files", comment: ""), transfer.files.count)
        }
        
        let mainMessage = String(format: NSLocalizedString("DeviceSendingFiles", value: "%1$@ is sending you %2$@", comment: ""), arguments: [device.name, fileStr])
        let pinCodeMessage = String(format:NSLocalizedString("PinCode", value: "PIN: %@", comment: ""), arguments: [transfer.pinCode!])
        let transferID = transfer.id
        
        alert.messageText = "QuickDrop - \(pinCodeMessage)"
        alert.informativeText = mainMessage
        alert.addButton(withTitle: NSLocalizedString("Accept", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Decline", comment: ""))
        
        let result = alert.runModal()
        
        if result == .alertFirstButtonReturn {
            
            if !isPlusVersion() && transmissionCount() > 0 {
                self.openPlusScreen {
                    self.continueTransmission(accept: self.isPlusVersion(), transferID: transferID)
                }
            }
            else {
                continueTransmission(accept: true, transferID: transferID)
            }
            
        } else if result == .alertSecondButtonReturn {
            
            continueTransmission(accept: false, transferID: transferID)
        }
    }
    
    func incomingTransfer(id: String, didFinishWith error: Error?) {
        guard let transfer = self.activeIncomingTransfers[id] else { return }
        if let error = error {
            
            let alert = NSAlert()
            alert.alertStyle = .critical
            
            alert.messageText = String(format: NSLocalizedString("TransferError", value: "Failed to receive files from %@", comment: ""), arguments: [transfer.device.name])
            var description = ""
            
            if let ne = (error as? NearbyError){
                switch ne {
                case .inputOutput:
                    description = "I/O Error";
                case .protocolError(_):
                    description = NSLocalizedString("Error.Protocol", value: "Communication error", comment: "")
                case .requiredFieldMissing:
                    description = NSLocalizedString("Error.Protocol", value: "Communication error", comment: "")
                case .ukey2:
                    description = NSLocalizedString("Error.Crypto", value: "Encryption error", comment: "")
                case .canceled(reason: _):
                    break; // can't happen for incoming transfers
                }
            } else {
                description = error.localizedDescription
            }
            
            alert.informativeText = description
            let _ = alert.runModal()
        }
        else {
            let currentCount = transmissionCount()
            
            if currentCount % 20 == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    SKStoreReviewController.requestReview()
                }
            }
            
            UserDefaults.standard.set(currentCount + 1, forKey: UserDefaultsKeys.transmissionCount.rawValue)
        }
        
        self.activeIncomingTransfers.removeValue(forKey: id)
    }
}


struct TransferInfo {
    let device: RemoteDeviceInfo
    let transfer: TransferMetadata
}
