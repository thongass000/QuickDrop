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
        
        PermissionView(title: "introduction_local_network_access", watchSymbol: "", subtitle: "introduction_local_network_access_description".localized(with: "introduction_continue".localized()), permissionAction: {
            
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
        }, continueLabel: "introduction_continue", canSkip: false, nextView: {
            IntroductionDoneView()
        }, nextViewSkip: {}, topView: {
            IntroductionIconView(icon: "wifi")
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
