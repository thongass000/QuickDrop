//
//  AlertManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 01.02.26.
//


import LUI
import SwiftUI

public final class IntroductionSheetManager: ObservableObject {
    
    public static let sharedInstance = IntroductionSheetManager()
    
    private var sheetView: NSPanel? = nil
    private var sheetAttachedWindow: NSWindow? = nil
    
    
    func openIntroductionWindow(on window: NSWindow, startReceiving: @escaping () -> Void, onFinish: @escaping () -> Void) {
        openSheetWindow(on: window, contentView: IntroductionView(startReceiving: startReceiving, onFinish: {
            self.closeSheetWindow()
            onFinish()
        }))
    }
    
    
    private func openSheetWindow<Content: View>(on window: NSWindow, contentView: Content) {
        if sheetView == nil {
            // Create the panel
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: IntroductionView.width, height: IntroductionView.height),
                styleMask: [.titled, .closable, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            
            // Set content (can be a NSHostingView for SwiftUI views)
            let hostingView = NSHostingView(rootView: contentView)
            panel.contentView = hostingView
            
            // Present as sheet
            window.beginSheet(panel, completionHandler: { response in
                log("[IntroductionSheetManager] Sheet dismissed with response: \(response)")
            })
            
            self.sheetAttachedWindow = window
            self.sheetView = panel
        }
    }
    

    func closeSheetWindow() {
        
        if let mainWindow = sheetAttachedWindow, let sheetView = sheetView {
            
            log("[IntroductionSheetManager] Closing sheetView window")
            
            mainWindow.endSheet(sheetView)

            self.sheetView = nil
            self.sheetAttachedWindow = nil
        }
    }
}
