//
//  TutorialView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.03.25.
//

import SwiftUI
import NearbyShare

struct TutorialView: View {
    
    let title: String
    let text: String
    let showsLicense: Bool
    var showsBetaJoinButton: Bool = false
    
    let openIAP: () -> Void
    
    @State private var licenseWindow: NSWindow?
    @State var taps = 0
    @AppStorage(UserDefaultsKeys.plusVersion.rawValue) var isPlusVersion = false
    
    var body: some View {
        
        LargeAppIconView(title: title) {
            VStack {
                Text(text.localized())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .frame(width: 550)
                
                
                if showsBetaJoinButton {
                    Button {
                        
                        let betaTextBottom = "BetaEmailBottom".localized()
                        
                        if let url = URL(string: "mailto:quickdrop-beta@leonboettger.com?subject=QuickDrop for Android Beta&body=\(betaTextBottom)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("JoinBeta")
                    }
                    .keyboardShortcut(.defaultAction)
                    .padding(.top)
                }
                
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
                        
                        if !isPlusVersion {
                            Button {
                                openIAP()
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
                            for key in UserDefaultsKeys.allCases {
                                UserDefaults.standard.removeObject(forKey: key.rawValue)
                            }
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
    @State var taps = 0
    
    var body: some View {
        ScrollView {
            
            VStack {
                Image("AppIconHighRes")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .padding(.top, 50)
                    .onTapGesture {
                        taps += 1
                        log("Clicked \(taps) times")
                        
                        if taps == 5 {
                            
                            sendLoggingString()
                            log("Copied log to clipboard")
                            
                            taps = 0
                        }
                    }
                
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

func sendLoggingString() {
    
    if let url = LogManager.sharedInstance.logFileURL {
        sendEmailWithAttachment(fileURL: url, recipients: ["quickdrop@leonboettger.com"], subject: "QuickDrop Log")
    }
    
    let logString = LogManager.sharedInstance.getLogString()
    
    copyToClipboard(logString)
}


func sendEmailWithAttachment(fileURL: URL, recipients: [String], subject: String) {
    guard let emailService = NSSharingService(named: .composeEmail) else {
        log("No email service available")
        return
    }
    
    emailService.recipients = recipients
    emailService.subject = subject
    emailService.perform(withItems: [fileURL])
}


func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}


#Preview {
    WelcomeScreen(openPlusScreen: {}, openAppAdvertisementView: {}, checkForNetworkIssues: {})
}
