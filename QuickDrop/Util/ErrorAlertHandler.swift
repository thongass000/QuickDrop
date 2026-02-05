//
//  ErrorAlertHandler.swift
//  QuickDrop
//
//  Created by Leon Böttger on 25.07.25.
//

import AudioToolbox
import Network
import StoreKit
import SwiftUI
import UserNotifications
import LUI

#if os(macOS)
import BezelNotification
import Cocoa
#endif

class ErrorAlertHandler {
    
    private init() {}
    static let shared = ErrorAlertHandler()
    
    private var isAlertShown = false
    #if os(macOS)
    private var firewallAlertWindow: NSWindow?
    private var apIsolationAlertWindow: NSWindow?
    private var networkFilterAlertWindow: NSWindow?
    #endif
    
    func showErrorAlert(for deviceName: String, error: Error) {
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        #endif
        
        var description = ""
        let fixInstructions = " " + "Error.FixInstructions".localized()
        
        if let ne = (error as? NearbyError) {
            switch ne {
            case .inputOutput:
                description = "I/O Error." + fixInstructions
            case .protocolError(errorMessage: let errorMessage):
                description = errorMessage + fixInstructions
            case .packetFilterError:
                #if os(macOS)
                openAlert(type: .NetworkFilter)
                return
                #else
                description = error.localizedDescription
                #endif
            case .firewallError:
                #if os(macOS)
                openAlert(type: .Firewall)
                return
                #else
                description = error.localizedDescription
                #endif
            case .requiredFieldMissing(errorMessage: let errorMessage):
                description = errorMessage + fixInstructions
            case .ukey2:
                description = "Error.Crypto".localized() + ": \(ne.localizedDescription)" + fixInstructions
            case .canceled(reason: let reason):
                if reason == .timedOut {
                    description = reason.localizedDescription() + fixInstructions
                }
                else {
                    description = reason.localizedDescription()
                }
            }
        } else {
            description = error.localizedDescription
        }
        
        // Prevent multiple alerts at the same time
        if self.isAlertShown {
            log("Skipping alert for error \(error.localizedDescription) because one is already shown")
            return
        }
        else {
            AudioManager.playErrorSound()
            
            let title = String(format: "TransferError".localized(), arguments: [deviceName])
            log("Showing alert with title: \"\(title)\" and description: \"\(description)\"")
            log("Unsuccessful transmission. Already successful transmissions: \(Settings.sharedInstance.incomingTransmissionCount)")
            
            #if os(macOS)
            
            let primaryButtonTitle = "InformDeveloper".localized()
            let secondaryButtonTitle = "CloseAlert".localized()
            
            self.isAlertShown = true
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = title
            alert.informativeText = description
            alert.addButton(withTitle: primaryButtonTitle)
            alert.addButton(withTitle: secondaryButtonTitle)
            
            let result = alert.runModal()
            self.isAlertShown = false
            
            if result == .alertFirstButtonReturn {
                //log("Sending logging string")
                //sendLoggingString()
            }
            #else
            showAlert(title: title, message: description)
            #endif
        }
    }
    

    #if os(macOS)
    func openAlert(type: AlertType) {
        log("Opening Alert for \(type)")
        AudioManager.playErrorSound()

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
    
    
    func closeApIsolationAlert() {
        log("Closing AP Isolation Alert")
        DispatchQueue.main.async {
            self.apIsolationAlertWindow?.close()
            self.apIsolationAlertWindow = nil
        }
    }
    #endif
}


enum AlertType: String {
    case ApIsolation
    case NetworkFilter
    case Firewall
}
