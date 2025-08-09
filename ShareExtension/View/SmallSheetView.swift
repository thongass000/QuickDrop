//
//  QrCodeView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.03.25.
//

import SwiftUI
import QRCode

let smallSheetViewSize = CGSize(width: 530.0, height: 270.0)

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
                
                HStack(spacing: 5) {
                    
                    let imageSize: CGFloat = type == .sendToDeviceQrCode ? 25 : 20
                    
                    Image(.quickDropIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize, height: imageSize)
                    
                    if type != .sendToDeviceQrCode {
                        Text("QuickDrop")
                    }
                }
                .padding(.leading, 18)
                
                if type == .sendToDeviceQrCode {
                    Spacer()
                    
                    HStack {
                        Text("ConnectWithQuickDropApp")
                            .padding(5)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(colorScheme == .light ? .white : .white.opacity(0.15)).opacity(connectWithApp ? 1 : 0))
                        
                        Text("ConnectWithoutApp")
                            .padding(5)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(colorScheme == .light ? .white : .white.opacity(0.15)).opacity(connectWithApp ? 0 : 1))
                    }
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
                
                Spacer()
                
                Button(action: {
                    closeView()
                }, label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                })
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.trailing, 15)
            .padding(.leading, 10)
            .padding(.top, 15)
            .padding(.bottom, type == .sendToDeviceQrCode ? 0 : -10)
            
            Spacer()
            
            HStack {
                Spacer()
                
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
                .frame(height: 160)
                
                Spacer()
               
                VStack {
                    Text(getDescription().localized())
                        .padding(.top, 5)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                    
                    if type == .downloadCableConnectionApp {
                        Button {
                            if let url = URL(string: "https://apps.apple.com/de/app/idroid-phone-file-manager/id6746444380") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Text("DownloadCableConnectionApp")
                        }
                        .keyboardShortcut(.defaultAction)
                        .padding()
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Spacer()
        
        }
        .frame(width: smallSheetViewSize.width, height: smallSheetViewSize.height)
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
        SmallSheetView(type: .sendToDeviceQrCode, dynamicQrCode: getImage(), closeView: {})
    }
    
    func getImage() -> Image {
        let qrCodeImage = try! QRCode.build
                    .text("https://quickshare.google/qrcode#key=AAA")
                    .backgroundColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0))
                    .quietZonePixelCount(2)
                    .onPixels.shape(.circle())
                    .eye.shape(.squircle())
                    .errorCorrection(.low)
                    .generate.image(dimension: 1000)
        
        return Image(nsImage: NSImage(cgImage: qrCodeImage, size: qrCodeImage.size))
    }
}
