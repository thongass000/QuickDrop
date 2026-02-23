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
import LUI

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    
    private var statusItem: NSStatusItem?

    var welcomeWindow: NSWindow?
    var plusWindow: NSWindow?
    
    private var sheetView: NSPanel? = nil
    private var sheetAttachedWindow: NSWindow? = nil
    private var errorAlertHandler = ErrorAlertHandler.shared

    private var receiveModel: ReceiveModel?

    var showsFirewallAlert = false
    var visibleItem: NSMenuItem? = nil

    
    // MARK: NSApplicationDelegate functions
    
    func applicationDidFinishLaunching(_: Notification) {
        
        let menu = NSMenu()

        let visibleItem = NSMenuItem(
            title: getDefaultVisibleLabel(),
            action: nil,
            keyEquivalent: ""
        )
        self.visibleItem = visibleItem
        menu.addItem(visibleItem)

        menu.addItem(NSMenuItem.separator())

        let sendClipboardItem = NSMenuItem(title: "SendClipboard".localized(), action: #selector(sendClipboard), keyEquivalent: "")
        sendClipboardItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        menu.addItem(sendClipboardItem)

        menu.addItem(NSMenuItem.separator())

        let userManualItem = NSMenuItem(title: "UserManual".localized(), action: #selector(openMainWindow), keyEquivalent: "")
        userManualItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        menu.addItem(userManualItem)

        let quitItem = NSMenuItem(title: "Quit".localized(), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quitItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        menu.addItem(quitItem)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(named: "MenuBarIcon")
        statusItem?.menu = menu
        statusItem?.behavior = .removalAllowed
        
        // app did not lauch before
        if !Settings.sharedInstance.appLaunchedBefore {
            log("[AppDelegate] Opening Welcome Screen")
            
            DispatchQueue.main.async {
                // open welcome screen in next cycle (await LUIInit)
                self.openMainWindow()
            }
            
            // user installed the app after the IAP was implemented, set the user as eligible for IAP
            Settings.sharedInstance.isEligibleForIap = true
        } else {
            // app launched before
            #if GITHUB
            log("[AppDelegate] Downloaded from GitHub.")
            #else
            // user installed the app before the IAP was implemented, grant the plus version
            if !Settings.sharedInstance.isEligibleForIap {
                log("[AppDelegate] Granting QuickDrop+ for old user")
                UserDefaults.standard.set(true, forKey: Settings.UserDefaultsKeys.plusVersionLegacy.rawValue)
            } else {
                if !fullVersion() {
                    log("[AppDelegate] New user - QuickDrop+ not available")
                }
                else {
                    log("[AppDelegate] QuickDrop+ available")
                }
            }
            #endif

            BezelNotification.show(messageText: "ReadyToReceive".localized(), icon: .receiveIcon)
            
            // only start receiving immediately for existing user, for new users we want to delay the permission prompt
            startReceiving()
        }
        
        LUIInit(configuration: configuration)

        UNUserNotificationCenter.current().delegate = self
        
        NearbyConnectionManager.shared.connectionUpdateCallback = { isConnected in
            if isConnected {
                self.statusItem?.button?.image = NSImage(named: "MenuBarIcon")
                self.visibleItem?.title = self.getDefaultVisibleLabel()
            }
            else {
                self.statusItem?.button?.image = NSImage(named: "MenuBarIconSlash")
                self.visibleItem?.title = "NoNetworkConnection".localized()
            }
        }
        
        NearbyConnectionManager.shared.changedDeviceNameCallback = {
            self.visibleItem?.title = self.getDefaultVisibleLabel()
        }
        
        log("[AppDelegate] Application did finish launching")
        log("[AppDelegate] Currently running apps: \(NSWorkspace.shared.runningApplications.map { $0.localizedName ?? "-" })")
    }
    
    
    func startReceiving() {
        guard receiveModel == nil else {
            log("[AppDelegate] startReceiving called while receiver is already active. Ignoring duplicate call.")
            return
        }

        receiveModel = ReceiveModel(controlPlusScreen: { shouldOpen in
            if shouldOpen {
                self.openPlusScreen()
            }
            else {
                if let window = self.plusWindow {
                    log("[AppDelegate] Closing plus screen because of error")
                    window.close()
                    self.plusWindow = nil
                }
            }
        })
    }
    
    
    func windowWillClose(_ notification: Notification) {
          if let window = notification.object as? NSWindow, window == welcomeWindow {
              log("[AppDelegate] Welcome window closed")
              welcomeWindow = nil
              NSApp.setActivationPolicy(.accessory)
          }
    }
    
    
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        self.openMainWindow()
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
        NearbyConnectionManager.shared.stopDeviceDiscovery()
        NearbyConnectionManager.shared.becomeInvisible()
    }
    
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "quickdrop" {
                
                switch url.host {
                    case "sendLog":
                        // If we're in an extension, redirect to the main app
                        if Bundle.main.bundlePath.hasSuffix(".appex") {
                            log("sendLoggingString: in extension, redirecting to main app")
                            
                            if let url = URL(string: "quickdrop://sendLog") {
                                NSWorkspace.shared.open(url)
                            }
                            return
                        }
                        
                        LogExportPresenter.copyLogsToClipboardAndShowAlert()
                    case "removeData":
                        Settings.sharedInstance.deleteAllUserDefaults()
                    default:
                        break
                }
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
        
        if clipboardString.isEmpty {
            DispatchQueue.main.async {
                BezelNotification.show(messageText: "ClipboardEmpty".localized(), icon: .clipboard)
            }
        }
        else {
            sendToSharingService(items: [clipboardString])
        }
    }

    
    @objc func openMainWindow() {
        defer {
            if let welcomeWindow, !Settings.sharedInstance.appLaunchedBefore {
                runAfter(seconds: 0.2) {
                    IntroductionSheetManager.sharedInstance.openIntroductionWindow(on: welcomeWindow, startReceiving: self.startReceiving) {
                        self.startReceiving()
                        Settings.sharedInstance.appLaunchedBefore = true
                    }
                }
            }
        }
        
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
            contentRect: NSRect(x: 0, y: 0, width: WelcomeScreen.width, height: WelcomeScreen.height),
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
            log("Plus screen already open, bringing to front")
            return
        }
        
        log("Opening Plus screen")

        // Create the welcome screen SwiftUI view
        let plusView = GetPlusViewV4(showSheet: Binding(get: { self.plusWindow != nil }, set: { newValue in
            if !newValue {
                self.plusWindow?.close()
                self.plusWindow = nil
            }
        }), hasSheet: false)
        
        let plusViewWidth: CGFloat = 750
        let plusViewHeight: CGFloat = 750

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
        window.level = .floating
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
    
    
    // MARK: - Helper Functions
    
    private func performDeviceToDeviceCheck() {
        let scanner = DeviceToDeviceHeuristicScanner.shared
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
    
    
    private func getDefaultVisibleLabel() -> String {
        let name = NearbyConnectionManager.shared.deviceInfo.name ?? "Unknown".localized()
        return String(format: "VisibleAs".localized(), name)
    }
}

struct TransferInfo {
    let device: RemoteDeviceInfo
    let transfer: TransferMetadata
}
