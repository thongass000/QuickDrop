//
//  WelcomeScreen.swift
//  QuickDrop
//
//  Created by Leon Böttger on 03.01.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct WelcomeScreen: View {
    
    internal init(
        openIntroduction: Bool,
        startReceiving: @escaping () -> Void,
        openPlusScreen: @escaping () -> Void,
        openAppAdvertisementView: @escaping () -> Void,
        openCableTransmissionView: @escaping () -> Void,
        checkForNetworkIssues: @escaping () -> Void
    ) {
        self._openedIntroduction = State(initialValue: openIntroduction)
        self.startReceiving = startReceiving
        self.openPlusScreen = openPlusScreen
        self.openAppAdvertisementView = openAppAdvertisementView
        self.openCableTransmissionView = openCableTransmissionView
        self.checkForNetworkIssues = checkForNetworkIssues
    }
    
    
    @Environment(\.colorScheme) var colorScheme
    
    let openPlusScreen: () -> Void
    let startReceiving: () -> Void
    let openAppAdvertisementView: () -> Void
    let openCableTransmissionView: () -> Void
    let checkForNetworkIssues: () -> Void
    
    @State private var selection: Tabs? = Tabs.receive
    @State private var openedIntroduction: Bool
    
    var body: some View {
        
        ZStack {
            
            if openedIntroduction {
                
                Image(.introductionBackground)
                    .resizable()
                    .ignoresSafeArea(.all)
                
                IntroductionSplashView(startReceiving: startReceiving) {
                    openedIntroduction = false
                }
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(25)
                .padding(.vertical, 60)
                .padding(.horizontal, 190)
            }
            else {
                
                HStack(spacing: 0) {
                    List(selection: $selection) {
                        ForEach(Tabs.allCases.filter({$0 != .settings }), id: \.self) { tab in
                            Label(tab.title, systemImage: tab.systemImage)
                                .tag(tab)
                                .frame(height: 30)
                        }
                        
                        Divider()
                        
                        ExternalLinkLabel(label: "GetSupport", icon: "questionmark.circle") {
                            sendLoggingString()
                        }
                        
                        ExternalLinkLabel(label: "PrivacyPolicy", icon: "hand.raised") {
                            openPrivacyPolicy()
                        }
                        
                        ExternalLinkLabel(label: "AndroidApp", icon: getPhoneIcon()) {
                            openAppAdvertisementView()
                        }
                        
                        ExternalLinkLabel(label: "TransmitUsingCable", icon: getCableIcon()) {
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
                        .opacity(colorScheme == .light ? 1 : 0.5)
                        .edgesIgnoringSafeArea(.vertical)
                    
                    ZStack {
                        Color.defaultBackground.edgesIgnoringSafeArea(.vertical)
                        
                        switch selection {
                        case .receive:
                            TutorialView(title: "ReceiveFiles", text: "UserManualDescription", showsLicense: true, openPlus: openPlusScreen)
                            
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
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
            }
        }
        .animation(.easeInOut, value: openedIntroduction)
        .frame(width: 1000, height: 600)
    }
    
    func openPrivacyPolicy() {
        if let url = URL(string: "https://leonboettger.com/quickdrop-privacy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func getPhoneIcon() -> String {
        if #available(macOS 14.0, *) {
            return "smartphone"
        }
        return "iphone.rear.camera"
    }
    
    func getCableIcon() -> String {
        if #available(macOS 12.0, *) {
            return "cable.connector"
        }
        return "externaldrive.connected.to.line.below.fill"
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        let dispatchGroup = DispatchGroup()
        var urls: [URL] = []
        let urlQueue = DispatchQueue(label: "DroppedURLsQueue")

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    defer { dispatchGroup.leave() }
                    if let data = item as? Data,
                       let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                        urlQueue.sync {
                            urls.append(url)
                        }
                    } else if let url = item as? URL {
                        urlQueue.sync {
                            urls.append(url)
                        }
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            if !urls.isEmpty {
                sendToSharingService(items: urls)
            }
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
    WelcomeScreen(openIntroduction: true, startReceiving: {}, openPlusScreen: {}, openAppAdvertisementView: {}, openCableTransmissionView: {}, checkForNetworkIssues: {})
}
