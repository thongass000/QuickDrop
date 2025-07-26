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
                    if let path = Bundle.main.path(forResource: "License", ofType: "txt"),
                       let licenseText = try? String(contentsOfFile: path) {
                        Text(licenseText)
                            .padding()
                    }
                    else {
                        Text(Bundle.main.path(forResource: "License", ofType: "txt") ?? "License file not found")
                    }
                }
            }
        }
    }
}


func openLicenseWindow() -> NSWindow {
    // Create a new NSWindow and retain it in the `newWindow` property
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
    NSApp.activate(ignoringOtherApps: true) // Brings the whole app to the front
    window.makeKeyAndOrderFront(nil)
    window.level = .normal
    
    // Retain the window to prevent deallocation
    return window
}
