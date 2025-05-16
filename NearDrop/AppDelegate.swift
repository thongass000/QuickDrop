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
import AudioToolbox
import BezelNotification
import Network

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, MainAppDelegate {
    
    private var statusItem: NSStatusItem?
    private var activeIncomingTransfers: [String : TransferInfo] = [:]
    
    var welcomeWindow: NSWindow?
    var plusWindow: NSWindow?
    var firewallAlertWindow: NSWindow?
    var apIsolationAlertWindow: NSWindow?
    var networkFilterAlertWindow: NSWindow?
    private var iapManager: IAPManager?
    
    var showsFirewallAlert = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let menu = NSMenu()
        
        menu.addItem(withTitle: NSLocalizedString("VisibleToEveryone", value: "Visible to everyone", comment: ""), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: String(format: NSLocalizedString("DeviceName", value: "Device name: %@", comment: ""), arguments: [Host.current().localizedName ?? "Mac"]), action: nil, keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())
        
        let sendClipboardItem = NSMenuItem(title: "SendClipboard".localized(), action: #selector(sendClipboard), keyEquivalent: "")
        menu.addItem(sendClipboardItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let userManualItem = NSMenuItem(title: NSLocalizedString("UserManual", value: "User Manual", comment: ""), action: #selector(openWelcomeScreen), keyEquivalent: "")
        menu.addItem(userManualItem)
        
        menu.addItem(withTitle: NSLocalizedString("Quit", value: "Quit QuickDrop", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(named: "MenuBarIcon")
        statusItem?.menu = menu
        statusItem?.behavior = .removalAllowed
        
        NearbyConnectionManager.shared.mainAppDelegate=self
        NearbyConnectionManager.shared.becomeVisible()
        
        iapManager = IAPManager.sharedInstance
        iapManager?.startObserving()
        
        // app did not lauch before
        if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.appLaunchedBefore.rawValue){
            
            log("Opening Welcome Screen")
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
                log("Granting QuickDrop+ for old user")
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.plusVersion.rawValue)
            }
            else {
                if !isPlusVersion() {
                    log("New user - QuickDrop+ not available")
                }
            }
            
            BezelNotification.show(messageText: "ReadyToReceive".localized(), icon: .receiveIcon)
        }
        
        UNUserNotificationCenter.current().delegate=self
        
        
        let hasConnection = isConnectedToNetwork()
        log("Currently used interface: \(getActiveNetworkInterface())")
        
        if hasConnection {
            let scanner = DeviceToDeviceHeuristicScanner()
            scanner.scan { allowed in
                if allowed {
                    log("✅ Device-to-device likely allowed (peer responded on LAN).")
                } else {
                    
                    let scanner2 = IPv6DeviceScanner()
                    scanner2.scan() { devices in
                        if devices.isEmpty {
                            log("❌ No local devices responded — peer-to-peer may be blocked.")
                            
                            self.openAlert(type: .ApIsolation)
                        } else {
                            log("✅ Found IPv6 devices (excluding router):")
                            for ip in devices {
                                print("  • \(ip)")
                            }
                        }
                    }
                }
            }
        }
        else {
            log("❌ Network unavailable, skipping device-to-device check.")
        }
    }
    
    
    @objc func sendClipboard() {
        if let fileURL = saveClipboardToTempFile() {
            
            let sharingService = NSSharingService(named: NSSharingService.Name("com.leonboettger.neardrop.ShareExtension"))
            
            sharingService?.perform(withItems: [fileURL])
        }
    }
    
    
    func saveClipboardToTempFile() -> URL? {
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string) ?? ""
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("Clipboard".localized() + ".txt")
        
        do {
            try clipboardString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            log("Failed to write file: \(error)")
            return nil
        }
    }
    
    
    @objc func openWelcomeScreen() {
        // Create the welcome screen SwiftUI view
        let welcomeView = WelcomeScreen {
            self.openPlusScreen()
        }
        
        // Create an NSWindow to host the SwiftUI view
        welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        welcomeWindow?.styleMask.insert(.fullSizeContentView)
        welcomeWindow?.titleVisibility = .hidden
        welcomeWindow?.titlebarAppearsTransparent = true
        
        welcomeWindow?.center()
        welcomeWindow?.isReleasedWhenClosed = false
        welcomeWindow?.setFrameAutosaveName("WelcomeScreen")
        welcomeWindow?.contentView = NSHostingView(rootView: welcomeView)
        
        // Ensure the window is always on top
        NSApp.activate(ignoringOtherApps: true) // Brings the whole app to the front
        welcomeWindow?.makeKeyAndOrderFront(nil)
        welcomeWindow?.level = .normal
    }
    
    
    @objc func openPlusScreen() {
        
        // Create the welcome screen SwiftUI view
        let plusView = GetPlusView(closeView: {
            log("Closing plus screen")
            self.plusWindow?.close()
        })
        
        // Create an NSWindow to host the SwiftUI view
        plusWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: plusViewWidth, height: plusViewHeight),
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
    
    enum AlertType: String {
        case ApIsolation
        case NetworkFilter
        case Firewall
    }
    
    
    func openAlert(type: AlertType) {
        DispatchQueue.main.async { [self] in
            
            // Create an NSWindow to host the SwiftUI view
            let alertWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: issueViewWidth, height: issueViewHeight),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            switch type {
            case .ApIsolation:
                apIsolationAlertWindow = alertWindow
                alertWindow.contentView = NSHostingView(rootView: ApIsolationIssueView())
            case .NetworkFilter:
                networkFilterAlertWindow = alertWindow
                alertWindow.contentView = NSHostingView(rootView: NetworkFilterIssueView())
            case .Firewall:
                firewallAlertWindow = alertWindow
                alertWindow.contentView = NSHostingView(rootView: FirewallIssueView())
            }
            
            alertWindow.title = "QuickDrop"
            alertWindow.center()
            alertWindow.isReleasedWhenClosed = false
            alertWindow.setFrameAutosaveName(type.rawValue)
            
            NSApp.activate(ignoringOtherApps: true)
            alertWindow.makeKeyAndOrderFront(nil)
            alertWindow.level = .normal
        }
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
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        
        openWelcomeScreen()
        statusItem?.isVisible=true
        return true
    }
    
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
         completionHandler([.sound, .banner])
     }
    
    
    func applicationWillTerminate(_ aNotification: Notification) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        iapManager?.stopObserving()
    }
    
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    
    public func continueTransmission(accept: Bool, transferID: String, storeInTemp: Bool = false) {
        NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: accept, storeInTemp: storeInTemp)
        
        if !accept {
            activeIncomingTransfers.removeValue(forKey: transferID)
        }
    }
    
    
    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
        self.activeIncomingTransfers[transfer.id] = TransferInfo(device: device, transfer: transfer)
        
        AudioManager.playSound()
        
        let acceptAutomatically = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticallyAcceptFiles.rawValue)
        
        let fileStr: String
        
        if let textTitle = transfer.textDescription {
            fileStr = textTitle
        } else if transfer.files.count == 1 {
            fileStr = transfer.files[0].name
        } else {
            fileStr = String.localizedStringWithFormat(NSLocalizedString("NFiles", value: "%d files", comment: ""), transfer.files.count)
        }
        
        let mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingFiles" : "DeviceSendingFiles").localized(), arguments: [device.name, fileStr])
        let pinCodeMessage = String(format:NSLocalizedString("PinCode", value: "PIN: %@", comment: ""), arguments: [transfer.pinCode ?? "?"])
        let transferID = transfer.id
        
        
        if acceptAutomatically {
            pressAcceptButton(transferID: transfer.id)
            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, err in
                if granted {
                    log("User granted notification permissions")
                    
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
        else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            
            alert.messageText = "QuickDrop - \(pinCodeMessage)"
            alert.informativeText = mainMessage
            alert.addButton(withTitle: NSLocalizedString("Accept", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Decline", comment: ""))
            
            let result = alert.runModal()
            
            if result == .alertFirstButtonReturn {
                pressAcceptButton(transferID: transferID)
            } else if result == .alertSecondButtonReturn {
                continueTransmission(accept: false, transferID: transferID)
            }
        }
    }
    
    
    private func pressAcceptButton(transferID: String) {
        if false || (!isPlusVersion() && transmissionCount() > 1) {
            
            self.continueTransmission(accept: true, transferID: transferID, storeInTemp: true)
            log("Showing plus screen...")
            
            self.openPlusScreen()
        }
        else {
            continueTransmission(accept: true, transferID: transferID)
        }
    }
    
    
    func showFirewallAlert() {
        openAlert(type: .Firewall)
    }
    
    
    func incomingTransfer(id: String, didFinishWith error: Error?) {
        guard let transfer = self.activeIncomingTransfers[id] else { return }
        if let error = error {
            
            var description = ""
            
            if let ne = (error as? NearbyError){
                switch ne {
                case .inputOutput:
                    description = "I/O Error";
                case .protocolError(_):
                    description = NSLocalizedString("Error.Protocol", value: "Communication error", comment: "") + "(\(ne.localizedDescription))"
                case .packetFilterError:
                    openAlert(type: .NetworkFilter)
                    plusWindow?.close()
                    return
                case .requiredFieldMissing:
                    description = NSLocalizedString("Error.Protocol", value: "Communication error", comment: "") + "(\(ne.localizedDescription))"
                case .ukey2:
                    description = NSLocalizedString("Error.Crypto", value: "Encryption error", comment: "") + "(\(ne.localizedDescription))"
                case .canceled(reason: _):
                    break // can't happen for incoming transfers
                }
            } else {
                description = error.localizedDescription
            }
            
            let alert = NSAlert()
            alert.alertStyle = .critical

            alert.messageText = String(format: NSLocalizedString("TransferError", value: "Failed to receive files from %@", comment: ""), arguments: [transfer.device.name])
            alert.informativeText = description
            
            alert.addButton(withTitle: "InformDeveloper".localized())
            alert.addButton(withTitle: "CloseAlert".localized())
            
            if let plusWindow = plusWindow {
                log("Closing plus screen because of error")
                plusWindow.close()
            }
            
            log("Showing alert with message: \"\(alert.messageText)\" and description: \"\(alert.informativeText)\"")
            
            let result = alert.runModal()
            
            if result == .alertFirstButtonReturn {
                sendLoggingString()
            }
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
