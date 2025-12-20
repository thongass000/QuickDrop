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
    
    let onFinish: (() -> Void)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZStack {
                    if colorScheme == .dark {
                        Color.black.opacity(0.2)
                        
                    }
                    else {
                        Color.white
                    }
                }
                .ignoresSafeArea()
                
                VStack() {
                    // Top Image
                    let topHeight = geo.size.height * 0.35
                    
                    ZStack {
                        
                        Color.gray.opacity(colorScheme == .light ? 0.1 : 0.12)
                        
                        currentPage.topHeader(with: topHeight)
                    }
                    .edgesIgnoringSafeArea(.top)
                    .frame(height: topHeight)
                    
                    
                    Spacer()
                    
                    VStack {
                        // Headline Text
                        Text(currentPage.title.localized())
                            .font(.system(size: 32))
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        
                        
                        // Subheadline
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
                    
                    // Buttons
                    HStack {
                        if let skipAction = currentPage.skipAction {
                            Button("introduction_skip") {
                                if let nextPage = skipAction() {
                                    currentPage = nextPage
                                }
                                else {
                                    onFinish()
                                }
                            }
                            .foregroundColor(.gray)
                            .buttonStyle(.borderless)
                        }
                        
                        Spacer()
                        
                        Button("introduction_continue") {
                            if let nextPage = currentPage.presentNextPage() {
                                currentPage = nextPage
                            }
                            else {
                                onFinish()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
        }
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
    
    var skipAction: (() -> IntroductionPage?)? {
        switch self {
        case .splash:
            return nil
        case .noWifi:
            return nil//{presentNextPage()}
        case .localNetworkAccess:
            return nil
        case .enableShareExtension:
            return nil//{presentNextPage()}
        case .finished:
            return nil
        }
    }
    
    func presentNextPage() -> IntroductionPage? {
        switch self {
        case .splash:
            return NearbyConnectionManager.shared.isConnectedToLocalNetwork ? .localNetworkAccess : .noWifi
        case .noWifi:
            return .localNetworkAccess
        case .localNetworkAccess:
            DeviceToDeviceHeuristicScanner().scan(completion: { _ in })
            return .enableShareExtension
        case .enableShareExtension:
            if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
            
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
}


#Preview {
    IntroductionSplashView{}
        .frame(width: 600, height: 500)
}
