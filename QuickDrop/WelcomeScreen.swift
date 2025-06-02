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
    let openAppAdvertisementView: () -> Void
    let openCableTransmissionView: () -> Void
    let checkForNetworkIssues: () -> Void
    
    @State private var selection: Tabs? = Tabs.receive
    
    var body: some View {
        
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(Tabs.allCases.filter({$0 != .settings }), id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                        .frame(height: 30)
                }
                
                Divider()
                
                ExternalLinkLabel(label: "GetSupport", icon: "questionmark.circle") {
                    getSupport()
                }
                
                ExternalLinkLabel(label: "PrivacyPolicy", icon: "hand.raised") {
                    openPrivacyPolicy()
                }
                
                ExternalLinkLabel(label: "AndroidApp", icon: "smartphone") {
                    openAppAdvertisementView()
                }
                
                ExternalLinkLabel(label: "TransmitUsingCable", icon: "cable.connector") {
                    openCableTransmissionView()
                }
                
                Divider()
                
                Label(Tabs.settings.title, systemImage: Tabs.settings.systemImage)
                    .tag(Tabs.settings)
                    .frame(height: 30)
            }
            .minimumScaleFactor(0.5)
            .frame(width: 220)
            .listStyle(SidebarListStyle())
            
            Divider()
                .opacity(colorScheme == .light ? 1 : 0)
                .edgesIgnoringSafeArea(.vertical)
            
            ZStack {
                Color.defaultBackground.edgesIgnoringSafeArea(.vertical)
                
                switch selection {
                case .receive:
                    TutorialView(title: "WelcomeToQuickDrop", text: "UserManualDescription", showsLicense: true, openPlus: openPlusScreen)
                    
                case .send:
                    TutorialView(title: "SendFiles", text: "SendFilesDescription", showsLicense: false, openPlus: openPlusScreen)
                    
                case .troubleshooting:
                    TutorialView(title: "Troubleshooting", text: "TroubleshootingDescription", showsLicense: false, openPlus: openPlusScreen)
                        .onAppear {
                            checkForNetworkIssues()
                        }
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
        if let url = URL(string: "https://leonboettger.com/quickdrop-privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}


struct ExternalLinkLabel: View {
    
    let label: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Label(label.localized(), systemImage: icon)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .opacity(0.3)
            }
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


enum Tabs: CaseIterable {
    case receive
    case send
    case troubleshooting
    case settings
    
    var title: String {
        switch self {
        case .receive:
            return "ReceiveFiles".localized()
        case .send:
            return "SendFiles".localized()
        case .troubleshooting:
            return "DeviceNotShown".localized()
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
        }
    }
}


#Preview {
    WelcomeScreen(openPlusScreen: {}, openAppAdvertisementView: {}, openCableTransmissionView: {}, checkForNetworkIssues: {})
}
