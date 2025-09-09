//
//  TutorialView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.03.25.
//

import SwiftUI

struct TutorialView: View {
    
    let title: String
    let text: String
    let showsLicense: Bool
    let openPlus: () -> Void
    
    @State private var licenseWindow: NSWindow?
    @ObservedObject var settings = Settings.shared
    
    var body: some View {
        
        LargeAppIconView(title: title) {
            VStack {
                Text(text.localized())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .frame(width: 550)
                
                if showsLicense {
                    HStack(spacing: 30) {
                        
                        Button {
                            licenseWindow = openLicenseWindow()
                        } label: {
                            Text("Acknowledgements")
                                .underline()
                                .font(.footnote)
                                .opacity(0.5)
                        }
                        .buttonStyle(.plain)
                        
                        if !settings.gotPlus {
                            Button {
                                openPlus()
                            } label: {
                                Text("SupportQuickDrop")
                                    .underline()
                                    .font(.footnote)
                                    .opacity(0.5)
                            }
                            .buttonStyle(.plain)
                        }
                        
#if DEBUG
                        Button {
                            Settings.shared.deleteAllUserDefaults()
                        } label: {
                            Text("Reset UD")
                                .underline()
                                .font(.footnote)
                                .opacity(0.5)
                        }
                        .buttonStyle(.plain)
#endif
                    }
                    .padding()
                }
            }
        }
    }
}


struct LargeAppIconView<Content: View>: View {
    
    let title: String
    let bottomView: () -> Content
    
    var body: some View {
        ScrollView {
            
            VStack {
                Image("AppIconHighRes")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .padding(.top, 40)
                
                Text(title.localized())
                    .font(.largeTitle)
                    .padding()
                
                bottomView()
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }
}


#Preview {
    WelcomeScreen(openPlusScreen: {}, openAppAdvertisementView: {}, openCableTransmissionView: {}, checkForNetworkIssues: {})
}
