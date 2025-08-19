//
//  AppDelegate.swift
//  QuickDrop
//
//  Created by Grishka on 08.04.2023.
//

import AudioToolbox
import BezelNotification
import Cocoa
import Network
import StoreKit
import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate, MainAppDelegate {
    
    private var statusItem: NSStatusItem?
    private var activeIncomingTransfers: [String: TransferInfo] = [:]

    var welcomeWindow: NSWindow?
    var plusWindow: NSWindow?
    
    private var sheetView: NSPanel? = nil
    private var sheetAttachedWindow: NSWindow? = nil
    private var errorAlertHandler = ErrorAlertHandler.shared

    private var iapManager: IAPManager?

    var showsFirewallAlert = false
    var visibleItem: NSMenuItem? = nil
    let hasConnectionMonitor = NWPathMonitor()

    
    // MARK: NSApplicationDelegate functions
    
    func applicationDidFinishLaunching(_: Notification) {
        let menu = NSMenu()

        let visibleItem = NSMenuItem(
            title: "VisibleToEveryone".localized(),
            action: nil,
            keyEquivalent: ""
        )
        self.visibleItem = visibleItem
        menu.addItem(visibleItem)
        
        menu.addItem(withTitle: String(format: "DeviceName".localized(), arguments: [Host.current().localizedName ?? "Mac"]), action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let sendClipboardItem = NSMenuItem(title: "SendClipboard".localized(), action: #selector(sendClipboard), keyEquivalent: "")
        menu.addItem(sendClipboardItem)

        menu.addItem(NSMenuItem.separator())

        let userManualItem = NSMenuItem(title: "UserManual".localized(), action: #selector(openWelcomeScreen), keyEquivalent: "")
        menu.addItem(userManualItem)

        menu.addItem(withTitle: "Quit".localized(), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

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
        
        log("Application did finish launching")
    }
    
    
    func windowWillClose(_ notification: Notification) {
          if let window = notification.object as? NSWindow, window == welcomeWindow {
              log("Welcome window closed")
              welcomeWindow = nil
              NSApp.setActivationPolicy(.accessory)
          }
      }
    
    
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        openWelcomeScreen()
        statusItem?.isVisible = true
        return true
    }
    

    public func userNotificationCenter(_: UNUserNotificationCenter,
                                       willPresent _: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound, .banner])
    }
    

    func applicationWillTerminate(_: Notification) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        iapManager?.stopObserving()
    }
    
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "quickdrop", url.host == "sendLog" {
                sendLoggingString()
            }
            
            if url.scheme == "quickdrop", url.host == "openLog", let url = LogManager.sharedInstance.logFileURL {
                log("Opening log file: \(url)")
                // open folder containing the log file
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    
    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
    }

    
    // MARK: - Button Actions
    
    @objc func sendClipboard() {
       
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string) ?? ""
        
        let sharingService = NSSharingService(named: NSSharingService.Name("com.leonboettger.neardrop.ShareExtension"))
        sharingService?.perform(withItems: [clipboardString])
    }

    
    @objc func openWelcomeScreen() {
        
        NSApp.setActivationPolicy(.regular)
        
        if let window = welcomeWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let welcomeView = WelcomeScreen(
            openPlusScreen: openPlusScreen,
            openAppAdvertisementView: { self.openSheetView(type: .downloadAndroidApp) },
            openCableTransmissionView: { self.openSheetView(type: .downloadCableConnectionApp) },
            checkForNetworkIssues: performDeviceToDeviceCheck
        )

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
        welcomeWindow?.delegate = self

        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow?.makeKeyAndOrderFront(nil)
        welcomeWindow?.level = .normal
    }

    
    @objc func openPlusScreen() {
        // If window already exists and is visible, just bring it to the front
        if let window = plusWindow, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create the welcome screen SwiftUI view
        let plusView = PlusView(closeView: {
            log("Closing plus screen")
            self.plusWindow?.close()
        })

        // Create an NSWindow to host the SwiftUI view
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: plusViewWidth, height: plusViewHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("PlusScreen")
        window.contentView = NSHostingView(rootView: plusView)

        // Reset reference when closed by red button
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.plusWindow = nil
        }

        plusWindow = window

        // Ensure the window is always on top
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.level = .normal
    }
    
    
    private func openSheetView(type: SheetViewType) {
        if sheetView == nil {
            let contentView = SmallSheetView(type: type) {
                self.closeSheetView()
            }

            let hostingView = NSHostingView(rootView: contentView)

            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: smallSheetViewSize.width, height: smallSheetViewSize.height),
                                styleMask: [.titled, .closable, .utilityWindow],
                                backing: .buffered,
                                defer: false)

            panel.contentView = hostingView

            sheetView = panel

            if let mainWindow = NSApp.mainWindow {
                sheetAttachedWindow = mainWindow
                mainWindow.beginSheet(panel) { _ in }
            }
        }
    }
    

    private func closeSheetView() {
        if let mainWindow = sheetAttachedWindow, let sheetView = sheetView {
            mainWindow.endSheet(sheetView)

            self.sheetView = nil
            self.sheetAttachedWindow = nil
        }
    }
    
    
    // MARK: - Alerts and Notifications

    func showFirewallAlert() {
        ErrorAlertHandler.shared.openAlert(type: .Firewall)
    }
    
    
    func showCopiedToClipboardAlert() {
        DispatchQueue.main.async {
            BezelNotification.show(messageText: "InsertedIntoClipboard".localized(), icon: .clipboard)
        }
    }
    
    
    func showUnsupportedFileAlert(for device: RemoteDeviceInfo?) {
        
        DispatchQueue.main.async {
            
            AudioManager.playErrorSound()
            
            NSApp.activate(ignoringOtherApps: true)
            
            let alert = NSAlert()
            alert.alertStyle = .critical
            
            alert.messageText = String(format: "TransferError".localized(), arguments: [device?.name ?? "??"])
            alert.informativeText = "UnsupportedFileType".localized()
            
            alert.addButton(withTitle: "InformDeveloper".localized())
            alert.addButton(withTitle: "CloseAlert".localized())
            
            let _ = alert.runModal()
        }
    }

    
    // MARK: - Transfer Handling
    
    public func continueTransmission(accept: Bool, transferID: String, storeInTemp: Bool = false) {
        NearbyConnectionManager.shared.submitUserConsent(transferID: transferID, accept: accept, storeInTemp: storeInTemp)

        if !accept {
            activeIncomingTransfers.removeValue(forKey: transferID)
        }
    }
    

    func obtainUserConsent(for transfer: TransferMetadata, from device: RemoteDeviceInfo) {
        
        NSApp.activate(ignoringOtherApps: true)
        
        activeIncomingTransfers[transfer.id] = TransferInfo(device: device, transfer: transfer)

        AudioManager.playIncomingFileSound()

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
        
        switch transfer.type {
            case .file:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingFiles" : "DeviceSendingFiles").localized(), arguments: [device.name, fileStr])
            
            case .text:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingText" : "DeviceSendingText").localized(), arguments: [device.name, fileStr])
            
            case .url:
                mainMessage = String(format: (acceptAutomatically ? "DeviceCurrentlySendingUrl" : "DeviceSendingUrl").localized(), arguments: [device.name, fileStr])
        }
        
       
        let pinCodeMessage = String(format: "PinCode".localized(), arguments: [transfer.pinCode ?? "?"])
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
            alert.addButton(withTitle: "Accept".localized())
            alert.addButton(withTitle: "Decline".localized())

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
    

    func incomingTransfer(id: String, didFinishWith error: Error?) {

        if let error = error {
            
            if let plusWindow = plusWindow {
                log("Closing plus screen because of error")
                plusWindow.close()
            }
            
            ErrorAlertHandler.shared.showErrorAlert(for: activeIncomingTransfers[id]?.device.name ?? "Android", error: error)
        } else {
            let currentCount = transmissionCount()
            if currentCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    SKStoreReviewController.requestReview()
                }
            }

            UserDefaults.standard.set(currentCount + 1, forKey: UserDefaultsKeys.transmissionCount.rawValue)
            log("Successful transmission. Current count: \(currentCount)")
        }

        activeIncomingTransfers.removeValue(forKey: id)
    }
    
    
    // MARK: - Helper Functions
    
    private func performDeviceToDeviceCheck() {
        let scanner = DeviceToDeviceHeuristicScanner()
        scanner.scan { allowed in
            if allowed {
                log("✅ Device-to-device likely allowed (peer responded on LAN).")
                ErrorAlertHandler.shared.closeApIsolationAlert()
            } else {
                log("❌ Device-to-device check failed. Informing user...")
                ErrorAlertHandler.shared.openAlert(type: .ApIsolation)
            }
        }
    }
}

struct TransferInfo {
    let device: RemoteDeviceInfo
    let transfer: TransferMetadata
}
