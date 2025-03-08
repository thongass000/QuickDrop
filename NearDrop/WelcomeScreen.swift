//
//  WelcomeScreen.swift
//  QuickDrop
//
//  Created by Leon Böttger on 03.01.25.
//

import SwiftUI

struct WelcomeScreen: View {
    
    @AppStorage(UserDefaultsKeys.plusVersion.rawValue) var isPlusVersion = false
    @Environment(\.colorScheme) var colorScheme
    
    let openIAP: () -> Void
    
    @State private var selection: Tabs? = Tabs.receive
    
    var body: some View {
        
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(Tabs.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                      //  .font(.system(size: 13))
                        .tag(tab)
                        .frame(height: 30)
                }
            }
            .frame(width: 220)
            .listStyle(SidebarListStyle())
            
            Divider()
                .edgesIgnoringSafeArea(.vertical)
            
            switch selection {
            case .receive:
                TutorialView(title: "WelcomeToQuickDrop", text: "UserManualDescription", showsLicense: true, openIAP: openIAP)
                
            case .send:
                TutorialView(title: "SendFiles", text: "SendFilesDescription", showsLicense: false, openIAP: openIAP)
                
            default:
                TutorialView(title: "Troubleshooting", text: "TroubleshootingDescription", showsLicense: false, openIAP: openIAP)
            }
        }
        .frame(width: 1000, height: 600)
    }
}


enum Tabs: CaseIterable {
    case receive
    case send
    case troubleshooting
    
    var title: String {
        switch self {
        case .receive:
            return "ReceiveFiles".localized()
        case .send:
            return "SendFiles".localized()
        case .troubleshooting:
            return "DeviceNotShown".localized()
        }
    }
    
    var systemImage: String {
        switch self {
        case .receive:
            return "tray.and.arrow.down.fill"
        case .send:
            return "tray.and.arrow.up.fill"
        case .troubleshooting:
            return "exclamationmark.triangle.fill"
        }
    }
}


#Preview {
    WelcomeScreen(openIAP: {})
}
