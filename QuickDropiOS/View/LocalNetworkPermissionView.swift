//
//  LocalNetworkPermissionView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.11.25.
//

import SwiftUI
import LUI

public struct LocalNetworkPermissionView: View {
    
    @State var requestedLocalNetworkAccess = false
    @Environment(\.scenePhase) var scenePhase
    
    public var body: some View {
        
        PermissionView(title: "introduction_local_network_access", symbol: "", subtitle: "introduction_local_network_access_description", permissionAction: {
            
            if requestedLocalNetworkAccess {
                // Something went wrong, user pressed again on continue. In this case, just continue with setup
                IntroductionViewController.sharedInstance.canProceed = true
            }
            else {
                // init manager to force local network access prompt
                requestedLocalNetworkAccess = true
                let manager = NearbyConnectionManager.shared
                manager.startDeviceDiscovery()
            }
        }, canSkip: false, nextView: {
            IntroductionDoneView()
        }, nextViewSkip: {}, frontMockup: {
            AppMockupFrontView()
        }, backMockup: {
            SymbolMockupView(symbol: "globe")
        })
        .onChange(of: scenePhase) { newValue in
            
            // alert was removed from screen, app is foreground again -> continue with intro
            if newValue == .active && requestedLocalNetworkAccess {
                IntroductionViewController.sharedInstance.canProceed = true
            }
        }
    }
}


#Preview {
    NavigationView {
        LocalNetworkPermissionView()
    }
}
