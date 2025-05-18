//
//  AppDelegate.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

import AudioToolbox
import BezelNotification
import Cocoa
import NearbyShare
import Network
import StoreKit
import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, MainAppDelegate {
    
    private var statusItem: NSStatusItem?
    private var activeIncomingTransfers: [String: TransferInfo] = [:]

    var welcomeWindow: NSWindow?
    var plusWindow: NSWindow?
    var firewallAlertWindow: NSWindow?
    var apIsolationAlertWindow: NSWindow?
    var networkFilterAlertWindow: NSWindow?
    private var iapManager: IAPManager?

    var showsFirewallAlert = false
    var visibleItem: NSMenuItem? = nil
    let hasConnectionMonitor = NWPathMonitor()

    func applicationDidFinishLaunching(_: Notification) {
        let menu = NSMenu()

        let visibleItem = NSMenuItem(
            title: "VisibleToEveryone".localized(),
            action: nil,
            keyEquivalent: ""
        )
        self.visibleItem = visibleItem
        menu.addItem(visibleItem)
        
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

        NearbyConnectionManager.shared.mainAppDelegate = self
        NearbyConnectionManager.shared.becomeVisible()

        iapManager = IAPManager.sharedInstance
        iapManager?.startObserving()

        // app did not lauch before
        if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.appLaunchedBefore.rawValue) {
            log("Opening Welcome Screen")
            // open welcome screen
            openWelcomeScreen()
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.appLaunchedBefore.rawValue)

            // user installed the app after the IAP was implemented, set the user as eligible for IAP
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isEligibleForIap.rawValue)
        } else {
            // app launched before

            // user installed the app before the IAP was implemented, grant the plus version
            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.isEligibleForIap.rawValue) {
                log("Granting QuickDrop+ for old user")
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.plusVersion.rawValue)
            } else {
                if !isPlusVersion() {
                    log("New user - QuickDrop+ not available")
                }
            }

            BezelNotification.show(messageText: "ReadyToReceive".localized(), icon: .receiveIcon)
        }

        UNUserNotificationCenter.current().delegate = self

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if path.supportsIPv4 && !path.supportsIPv6 {
                    log("Detected IPv4-only network.")
                    self.performDeviceToDeviceCheck()
                } else if !path.supportsIPv4 && path.supportsIPv6 {
                    log("IPv6-only network, likely iPhone hotspot. Skipping device-to-device check.")
                } else if path.supportsIPv4 && path.supportsIPv6 {
                    log("Detected Dual stack network.")
                    self.performDeviceToDeviceCheck()
                } else {
                    log("Detected no IP support")
                }
            } else {
                log("Network unavailable")
            }

            monitor.cancel()
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        hasConnectionMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.statusItem?.button?.image = NSImage(named: "MenuBarIcon")
                    self.visibleItem?.title = "VisibleToEveryone".localized()
                } else {
                    self.statusItem?.button?.image = NSImage(named: "MenuBarIconSlash")
                    self.visibleItem?.title = "NoNetworkConnection".localized()
                }
            }
        }

        let queue2 = DispatchQueue(label: "NetworkConnectionMonitor")
        hasConnectionMonitor.start(queue: queue2)
    }

    func performDeviceToDeviceCheck() {
        let scanner = DeviceToDeviceHeuristicScanner()
        scanner.scan { allowed in
            if allowed {
                log("✅ Device-to-device likely allowed (peer responded on LAN).")
                self.apIsolationAlertWindow?.close()
            } else {
                
                log("❌ First check failed. Retrying in 10 seconds...")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    scanner.scan { allowed in
                        if allowed {
                            log("✅ Device-to-device likely allowed (peer responded on LAN).")
                            self.apIsolationAlertWindow?.close()
                        } else {
                            log("❌ Second check failed. Informing user...")
                            self.openAlert(type: .ApIsolation)
                        }
                    }
                }
            }
        }
    }

    @objc func sendClipboard() {
       
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string) ?? ""
        
        let sharingService = NSSharingService(named: NSSharingService.Name("com.leonboettger.neardrop.ShareExtension"))
        sharingService?.perform(withItems: [clipboardString])
    }

    @objc func openWelcomeScreen() {
        // Create the welcome screen SwiftUI view
        let welcomeView = WelcomeScreen(openPlusScreen: openPlusScreen, checkForNetworkIssues: performDeviceToDeviceCheck)

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

        plusWindow?.styleMask.insert(.fullSizeContentView)
        plusWindow?.titleVisibility = .hidden
        plusWindow?.titlebarAppearsTransparent = true

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
        log("Opening Alert for \(type)")

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
                alertWindow.contentView = NSHostingView(rootView: ApIsolationIssueView(closeView: { self.apIsolationAlertWindow?.close() }))
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

    // Action for "Recommended Apps" menu item
    @objc func openRecommendedApps() {
        if let url = URL(string: "https://apps.apple.com/de/developer/leon-boettger/id1537384790") {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        openWelcomeScreen()
        statusItem?.isVisible = true
        return true
    }

    public func userNotificationCenter(_: UNUserNotificationCenter,
                                       willPresent _: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.sound, .banner])
    }

    func applicationWillTerminate(_: Notification) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        iapManager?.stopObserving()
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
    }

    public func continueTransmission(accept: Bool, transferID: String, storeInTemp: Bool = false) {
        NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: accept, storeInTemp: storeInTemp)

        if !accept {
            activeIncomingTransfers.removeValue(forKey: transferID)
        }
    }

    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
        
        NSApp.activate(ignoringOtherApps: true)
        
        activeIncomingTransfers[transfer.id] = TransferInfo(device: device, transfer: transfer)

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

        
        let mainMessage: String
        
        switch transfer.type {
            case .file:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingFiles" : "DeviceSendingFiles").localized(), arguments: [device.name, fileStr])
            
            case .text:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingText" : "DeviceSendingText").localized(), arguments: [device.name, fileStr])
            
            case .url:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingUrl" : "DeviceSendingUrl").localized(), arguments: [device.name, fileStr])
        }
        
       
        let pinCodeMessage = String(format: NSLocalizedString("PinCode", value: "PIN: %@", comment: ""), arguments: [transfer.pinCode ?? "?"])
        let transferID = transfer.id

        if acceptAutomatically {
            pressAcceptButton(transferID: transfer.id)

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
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
        } else {
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
        if isFileTransferRestricted() {
            continueTransmission(accept: true, transferID: transferID, storeInTemp: true)
            log("Showing plus screen...")

            openPlusScreen()
        } else {
            continueTransmission(accept: true, transferID: transferID)
        }
    }

    func showFirewallAlert() {
        openAlert(type: .Firewall)
    }
    
    func showCopiedToClipboardAlert() {
        DispatchQueue.main.async {
            BezelNotification.show(messageText: "InsertedIntoClipboard".localized(), icon: .clipboard)
        }
    }
    
    func showUnsupportedFileAlert(for device: RemoteDeviceInfo?) {
        
        DispatchQueue.main.async {
            
            NSApp.activate(ignoringOtherApps: true)
            
            let alert = NSAlert()
            alert.alertStyle = .critical
            
            alert.messageText = String(format: NSLocalizedString("TransferError", value: "Failed to receive files from %@", comment: ""), arguments: [device?.name ?? "??"])
            alert.informativeText = "UnsupportedFileType".localized()
            
            alert.addButton(withTitle: "InformDeveloper".localized())
            alert.addButton(withTitle: "CloseAlert".localized())
            
            let _ = alert.runModal()
        }
    }

    func incomingTransfer(id: String, didFinishWith error: Error?) {
        
        guard let transfer = activeIncomingTransfers[id] else { return }
        
        if let error = error {
            
            NSApp.activate(ignoringOtherApps: true)
            
            var description = ""

            if let ne = (error as? NearbyError) {
                switch ne {
                case .inputOutput:
                    description = "I/O Error"
                case .protocolError:
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
        } else {
            let currentCount = transmissionCount()

            if currentCount % 20 == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    SKStoreReviewController.requestReview()
                }
            }

            UserDefaults.standard.set(currentCount + 1, forKey: UserDefaultsKeys.transmissionCount.rawValue)
        }

        activeIncomingTransfers.removeValue(forKey: id)
    }
}

struct TransferInfo {
    let device: RemoteDeviceInfo
    let transfer: TransferMetadata
}
