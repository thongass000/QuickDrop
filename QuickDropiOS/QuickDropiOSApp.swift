//
//  QuickDropiOSApp.swift
//  QuickDropiOS
//
//  Created by Leon Böttger on 28.07.25.
//

import SwiftUI
import LUI

@main
struct QuickDropiOSApp: App {
    
    #if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        LUIInit(configuration: configuration)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
