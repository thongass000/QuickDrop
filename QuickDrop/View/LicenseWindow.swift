//
//  LicenseWindow.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.03.25.
//

import SwiftUI


struct LicensePage: View {
    var body: some View {
        ZStack {
            Color.defaultBackground
                .edgesIgnoringSafeArea(.all)
            ScrollView {
                LazyVStack {
                    Text(licenseText)
                }
            }
        }
    }
}


func openLicenseWindow() -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.center()
    window.isReleasedWhenClosed = false
    window.title = "Acknowledgements".localized()
    window.contentView = NSHostingView(rootView: LicensePage())
    
    // Ensure the window is always on top
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    window.level = .normal
    
    return window
}
