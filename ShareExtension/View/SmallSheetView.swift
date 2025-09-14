//
//  QrCodeView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.03.25.
//

import SwiftUI
import QRCode

#if os(macOS)
let smallSheetViewSize = CGSize(width: 530.0, height: 270.0)
#endif

struct SmallSheetView: View {
    @State private var qrCode: String = ""
    
    let type: SheetViewType
    var dynamicQrCode: Image? = nil
    let closeView: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("connectWithApp") var connectWithApp = false
    
    var body: some View {
  
        VStack {
            
            HStack {
                
                #if os(macOS)
                HStack(spacing: 5) {
                    
                    let imageSize: CGFloat = type == .sendToDeviceQrCode ? 25 : 20
                    
                    Image(.quickDropIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize, height: imageSize)
                    
                    if type != .sendToDeviceQrCode {
                        Text(String("QuickDrop"))
                    }
                }
                .padding(.leading, 18)
                #endif
                
                if type == .sendToDeviceQrCode {
                    
                    #if os(macOS)
                    Spacer()
                    #endif
                    
                    HStack {
                        
                        Text("ConnectWithQuickDropApp")
                            .padding(5)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(colorScheme == .light ? .white : .white.opacity(0.15)).opacity(connectWithApp ? 1 : 0))
                        
                        ZStack {
                            Text("ConnectWithoutApp")
                            Text("ConnectWithQuickDropApp")
                                .opacity(0) // keep size for label the same
                        }
                        .padding(5)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(colorScheme == .light ? .white : .white.opacity(0.15)).opacity(connectWithApp ? 0 : 1))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 1)
                    .padding(4)
                    .background(Capsule().fill(Color.gray.opacity(colorScheme == .light ? 0.2 : 0.15)))
                    .onTapGesture {
                        withAnimation {
                            connectWithApp.toggle()
                        }
                    }
                    .animation(.smooth, value: connectWithApp)
                }
                
                
                #if os(macOS)
                
                Spacer()
                
                Button(action: {
                    closeView()
                }, label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                })
                .buttonStyle(PlainButtonStyle())
                #endif
            }
            .padding(.trailing, 15)
            .padding(.leading, 10)
            .padding(.top, 15)
            .padding(.bottom, type == .sendToDeviceQrCode ? 0 : -10)
            
            Spacer()
            
            #if os(macOS)
            HStack {
                Spacer()
                imageView
                Spacer()
                descriptionView
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
            #else
            imageView
                .frame(maxWidth: 300)
                .padding(.horizontal, 30)
            Spacer()
            descriptionView
            #endif
            
            Spacer()
        
        }
        #if os(macOS)
        .frame(width: smallSheetViewSize.width, height: smallSheetViewSize.height)
        #endif
    }
    
    
    var imageView: some View {
        ZStack {
            if type == .sendToDeviceQrCode && dynamicQrCode != nil {
                Image(.qrBackground)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
            }
            
            getImage()
                .resizable()
                .aspectRatio(1, contentMode: .fit)
        }
        #if os(macOS)
        .frame(height: 160)
        #endif
    }
    
    
    var descriptionView: some View {
        VStack {
            Text(getDescription().localized())
                .padding(.top, 5)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
            
            #if !(EXTENSION && os(iOS))
            if type == .downloadCableConnectionApp {
                Button {
                    if let url = URL(string: "https://apps.apple.com/de/app/idroid-phone-file-manager/id6746444380") {
                        #if os(iOS)
                        UIApplication.shared.open(url)
                        #else
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                } label: {
                    Text("DownloadCableConnectionApp")
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
            #endif
        }
    }
    
    
    func getDescription() -> String {
        
        switch type {
        case .sendToDeviceQrCode:
            return connectWithApp ? "QrCodeInstructionsApp" : "QrCodeInstructions"
        case .downloadAndroidApp:
            return "QuickDropAndroidAppAdvertisement"
        case .downloadCableConnectionApp:
            return "DownloadCableConnectionAppDescription"
        }
    }
    
    func getImage() -> Image {
        switch type {
        case .sendToDeviceQrCode:
            return connectWithApp ? Image(.qrApp) : (dynamicQrCode ?? Image(.QR))
        case .downloadAndroidApp:
            return Image(.qrApp)
        case .downloadCableConnectionApp:
            return Image(.iDroid)
        }
    }
}


enum SheetViewType {
    case sendToDeviceQrCode
    case downloadAndroidApp
    case downloadCableConnectionApp
}


#Preview {
    Preview()
}


private struct Preview: View {
    var body: some View {
        SmallSheetView(type: .sendToDeviceQrCode, dynamicQrCode: NearbyConnectionManager.shared.generateQrCodeKey(), closeView: {})
    }
}
