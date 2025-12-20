//
//  IntroductionSplashView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 20.12.25.
//

import SwiftUI
import LUI

struct IntroductionSplashView: View {

    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage: IntroductionPage = .splash

    @State private var pollingPage: IntroductionPage? = nil
    @State private var skipAction: IntroductionPage.SkipAction? = nil
    
    let startReceiving: (() -> Void)
    let onFinish: (() -> Void)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZStack {
                    if colorScheme == .dark {
                        Color.black.opacity(0.2)
                    } else {
                        Color.white
                    }
                }
                .ignoresSafeArea()

                VStack {
                    let topHeight = geo.size.height * 0.35

                    ZStack {
                        Color.gray.opacity(colorScheme == .light ? 0.1 : 0.12)
                        currentPage.topHeader(with: topHeight)
                    }
                    .edgesIgnoringSafeArea(.top)
                    .frame(height: topHeight)

                    Spacer()

                    VStack {
                        Text(currentPage.title.localized())
                            .font(.system(size: 32))
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(currentPage.subtitle.localized())
                            .font(.system(size: 15))
                            .lineSpacing(5)
                            .multilineTextAlignment(.center)
                            .padding(.top)
                            .minimumScaleFactor(0.5)
                            .opacity(0.8)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                    Spacer()

                    Divider()

                    HStack {
                        if let skipAction = currentPage.skipAction {
                            Button("introduction_skip") {
                                self.skipAction = skipAction
                            }
                            .foregroundColor(.gray)
                            .buttonStyle(.borderless)
                            .alert(item: $skipAction) { action in
                                
                                .init(title: Text(action.warningTitle.localized()), message: Text(action.warningMessage.localized()), primaryButton: .default(Text("introduction_skip".localized()), action: {
                                    
                                    stopPolling()
                                    self.skipAction = nil
                                    
                                    if let nextPage = action.action() {
                                        currentPage = nextPage
                                    }
                                    else {
                                        onFinish()
                                    }
                                }), secondaryButton: .cancel()
                                )
                            }
                        }

                        Spacer()

                        continueArea
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
        }
        .onAppear { pageDidChange(to: currentPage) }
        .onChange(of: currentPage) { newValue in
            pageDidChange(to: newValue)
        }
        .task(id: pollingPage) {
            guard let page = pollingPage else { return }

            // Poll every 1 second until condition is satisfied or canceled
            while !Task.isCancelled {
                if page.canContinue() {
                    await MainActor.run {
                        // Only advance if we're still on the page we started polling for
                        guard currentPage == page else {
                            stopPolling()
                            return
                        }
                        stopPolling()
                        advance()
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    @ViewBuilder
    private var continueArea: some View {
        ZStack {
            
            let isLoading = pollingPage != nil
            
            Button("introduction_continue") {
                continueTapped()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .opacity(isLoading ? 0 : 1)
            .overlay (
                LoadingIndicator()
                    .frame(width: 20, height: 20)
                    .opacity(isLoading ? 1 : 0)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            )
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        
    }

    private func pageDidChange(to newPage: IntroductionPage) {
        stopPolling()

        // Cannot perform action, default to loading screen
        if !newPage.canPerformAction {
            pollingPage = newPage
        }
    }

    private func continueTapped() {
        // If already allowed, advance immediately
        if currentPage.canContinue() {
            advance()
            return
        }

        // Not allowed yet: show loading and start polling every 1s
        pollingPage = currentPage

        // Page-specific "kickoff" action that should happen only after user presses continue
        if currentPage == .enableShareExtension {
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func triggerLocalNetworkPermission() {
        self.startReceiving()
        
        // just to be sure it is triggered
        runAfter(seconds: 1) {
            DeviceToDeviceHeuristicScanner.shared.scan(completion: { _ in })
        }
    }

    private func advance() {
        
        if currentPage == .localNetworkAccess {
            triggerLocalNetworkPermission()
        }
        
        if let nextPage = currentPage.presentNextPage() {
            currentPage = nextPage
        } else {
            onFinish()
        }
    }

    private func stopPolling() {
        // Cancels the .task(id:) by changing the id and resets UI state
        pollingPage = nil
    }
}



enum IntroductionPage: CaseIterable {
    case splash
    case noWifi
    case localNetworkAccess
    case enableShareExtension
    case finished
    
    var title: String {
        switch self {
        case .splash:
            return "WelcomeToQuickDrop"
        case .noWifi:
            return "introduction_no_wifi"
        case .localNetworkAccess:
            return "introduction_local_network_access"
        case .enableShareExtension:
            return "introduction_enable_share_extension"
        case .finished:
            return "introduction_finished"
        }
    }
    
    var subtitle: String {
        switch self {
        case .splash:
            return "QuickDropWelcomeDescription"
        case .noWifi:
            return "introduction_no_wifi_description"
        case .localNetworkAccess:
            return "introduction_local_network_access_description"
        case .enableShareExtension:
            return "introduction_enable_share_extension_description"
        case .finished:
            return "introduction_finished_description"
        }
    }
    
    var skipAction: SkipAction? {
        switch self {
        case .splash:
            return nil
        case .noWifi:
            return .init(action: {presentNextPage()}, warningTitle: "introduction_no_wifi_skip_title", warningMessage: "introduction_no_wifi_skip_message", id: "noWifiSkip")
        case .localNetworkAccess:
            return nil
        case .enableShareExtension:
            return .init(action: {presentNextPage()}, warningTitle: "introduction_enable_share_extension_skip_title", warningMessage: "introduction_enable_share_extension_skip_message", id: "enableShareExtensionSkip")
        case .finished:
            return nil
        }
    }
    
    var canPerformAction: Bool {
        switch self {
            case .noWifi:
                return false
            default:
                return true
        }
    }
    
    func presentNextPage() -> IntroductionPage? {
        switch self {
        case .splash:
            return NearbyConnectionManager.shared.isConnectedToLocalNetwork ? .localNetworkAccess : .noWifi
        case .noWifi:
            return .localNetworkAccess
        case .localNetworkAccess:
            return .enableShareExtension
        case .enableShareExtension:
            return .finished
        case .finished:
            return nil
        }
    }
    
    func canContinue() -> Bool {
        switch self {
            case .noWifi:
                return NearbyConnectionManager.shared.isConnectedToLocalNetwork
            case .enableShareExtension:
                return NSSharingService(named: NSSharingService.Name("com.leonboettger.neardrop.ShareExtension")) != nil
            default:
                return true
        }
    }
    
    func topHeader(with height: CGFloat) -> some View {
        ZStack {
            
            switch self {
            case .splash:
                Image(.quickDropMockup)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, height * 0.33)
                    .padding(.bottom, height * 0.1)
            case .noWifi:
                imageView(for: "wifi.slash", with: height)
            case .localNetworkAccess:
                imageView(for: "network", with: height)
            case .enableShareExtension:
                imageView(for: "square.and.arrow.up", with: height)
            case .finished:
                imageView(for: "checkmark.seal.fill", with: height)
            }
            
        }
        .foregroundColor(.blue)
    }
    
    private func imageView(for image: String, with height: CGFloat) -> some View {
        Image(systemName: image)
            .resizable()
            .scaledToFit()
            .frame(height: height * 0.5)
            .padding(.top, height * 0.13)
    }
    
    struct SkipAction: Identifiable {
        let action: () -> IntroductionPage?
        let warningTitle: String
        let warningMessage: String
        
        let id: String
    }
}


#Preview {
    IntroductionSplashView(startReceiving: {}){}
        .frame(width: 600, height: 500)
}
