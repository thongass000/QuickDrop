//
//  QrCodeView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.03.25.
//

import SwiftUI

let qrCodeViewSize = CGSize(width: 530.0, height: 270.0)

struct QrCodeView: View {
    @State private var qrCode: String = ""
    var advertisesApp = false
    let closeView: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("connectWithApp") var connectWithApp = true
    
    var body: some View {
  
        VStack {
            
            HStack {
                
                if !advertisesApp {
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
                    .animation(.smooth, value:connectWithApp)
                }
                else {
                    HStack(spacing: 5) {
                        Image(.quickDropIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        
                        Text("QuickDrop")
                    }
                    .padding(.leading, 18)
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
            .padding(.bottom, advertisesApp ? -10 : 0)
            
            Spacer()
            
            HStack {
                Spacer()
                
                Image(connectWithApp ? .qrApp : .QR)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(height: 160)
                
                Spacer()
               
                
                Text(getDescription().localized())
                    .padding(.top, 5)
                    .padding(.horizontal)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Spacer()
        
        }
        .frame(width: qrCodeViewSize.width, height: qrCodeViewSize.height)
    }
    
    func getDescription() -> String {
        
        if advertisesApp {
            return "QuickDropAndroidAppAdvertisement"
        }
        
        return connectWithApp ? "QrCodeInstructionsApp" : "QrCodeInstructions"
    }
}

#Preview {
    QrCodeView(closeView: {})
}
