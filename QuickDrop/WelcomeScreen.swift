//
//  WelcomeScreen.swift
//  QuickDrop
//
//  Created by Leon Böttger on 03.01.25.
//

import SwiftUI
import NearbyShare

struct WelcomeScreen: View {
    
    @AppStorage(UserDefaultsKeys.plusVersion.rawValue) var isPlusVersion = false
    @Environment(\.colorScheme) var colorScheme
    
    let openPlusScreen: () -> Void
    let checkForNetworkIssues: () -> Void
    
    @State private var selection: Tabs? = Tabs.receive
    
    var body: some View {
        
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(Tabs.allCases.filter({$0 != .settings && $0 != .app}), id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                      //  .font(.system(size: 13))
                        .tag(tab)
                        .frame(height: 30)
                }
                
                Divider()
                
                Button {
                    getSupport()
                } label: {
                    HStack {
                        Label("GetSupport", systemImage: "questionmark.circle")
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .opacity(0.3)
                    }
                }
                .buttonStyle(.plain)
                    .frame(height: 30)
                
                
                Button {
                    openPrivacyPolicy()
                
                } label: {
                    
                    HStack {
                        Label("PrivacyPolicy", systemImage: "hand.raised")
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .opacity(0.3)
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 30)
                
                Divider()
                
                Label(Tabs.settings.title, systemImage: Tabs.settings.systemImage)
                    .tag(Tabs.settings)
                    .frame(height: 30)
                
                Label(Tabs.app.title, systemImage: Tabs.app.systemImage)
                    .tag(Tabs.app)
                    .frame(height: 30)
            }
            .frame(width: 220)
            .listStyle(SidebarListStyle())
            
            Divider()
                .opacity(colorScheme == .light ? 1 : 0)
                .edgesIgnoringSafeArea(.vertical)
            
            ZStack {
                Color.defaultBackground.edgesIgnoringSafeArea(.vertical)
                
                switch selection {
                case .receive:
                    TutorialView(title: "WelcomeToQuickDrop", text: "UserManualDescription", showsLicense: true, openIAP: openPlusScreen)
                    
                case .send:
                    TutorialView(title: "SendFiles", text: "SendFilesDescription", showsLicense: false, openIAP: openPlusScreen)
                    
                case .troubleshooting:
                    TutorialView(title: "Troubleshooting", text: "TroubleshootingDescription", showsLicense: false, openIAP: openPlusScreen)
                    
                case .app:
                    TutorialView(title: "AndroidApp", text: "AndroidAppDescription", showsLicense: false, showsBetaJoinButton: true, openIAP: openPlusScreen)
                    
                default:
                    SettingsView()
                }
            }
        }
        .frame(width: 1000, height: 600)
    }
    
    func getSupport() {
        if let url = URL(string: "mailto:quickdrop@leonboettger.com?subject=QuickDrop") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "http://leonboettger.com/privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}


enum Tabs: CaseIterable {
    case receive
    case send
    case troubleshooting
    case app
    case settings
    
    var title: String {
        switch self {
        case .receive:
            return "ReceiveFiles".localized()
        case .send:
            return "SendFiles".localized()
        case .troubleshooting:
            return "DeviceNotShown".localized()
        case .app:
            return "AndroidApp".localized()
        case .settings:
            return "Settings".localized()
        }
    }
    
    var systemImage: String {
        switch self {
        case .receive:
            return "tray.and.arrow.down"
        case .send:
            return "tray.and.arrow.up"
        case .troubleshooting:
            return "exclamationmark.triangle"
        case .settings:
            return "gear"
        case .app:
            return "smartphone"
        }
    }
}


#Preview {
    WelcomeScreen(openPlusScreen: {}, checkForNetworkIssues: {})
}
