//
//  CableConnectionView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 02.06.25.
//

//import SwiftUI
//
//struct CableConnectionView: View {
//    let closeView: () -> Void
//    
//    @Environment(\.colorScheme) var colorScheme
//    
//    var body: some View {
//  
//        VStack {
//            
//            HStack {
//                
//                HStack(spacing: 5) {
//                    
//                    let imageSize: CGFloat = advertisesApp ? 20 : 25
//                    
//                    Image(.quickDropIcon)
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: imageSize, height: imageSize)
//                    
//                    if advertisesApp {
//                        Text("QuickDrop")
//                    }
//                }
//                .padding(.leading, 18)
//                
//                if !advertisesApp {
//                    Spacer()
//                    
//                    HStack {
//                        Text("ConnectWithQuickDropApp")
//                            .padding(5)
//                            .padding(.horizontal, 4)
//                            .background(Capsule().fill(colorScheme == .light ? .white : .white.opacity(0.15)).opacity(connectWithApp ? 1 : 0))
//                        
//                        Text("ConnectWithoutApp")
//                            .padding(5)
//                            .padding(.horizontal, 4)
//                            .background(Capsule().fill(colorScheme == .light ? .white : .white.opacity(0.15)).opacity(connectWithApp ? 0 : 1))
//                    }
//                    .padding(.horizontal, 1)
//                    .padding(4)
//                    .background(Capsule().fill(Color.gray.opacity(colorScheme == .light ? 0.2 : 0.15)))
//                    .onTapGesture {
//                        withAnimation {
//                            connectWithApp.toggle()
//                        }
//                    }
//                    .animation(.smooth, value:connectWithApp)
//                }
//                
//                Spacer()
//                
//                Button(action: {
//                    closeView()
//                }, label: {
//                    Image(systemName: "xmark")
//                        .font(.system(size: 20))
//                        .foregroundColor(.gray)
//                })
//                .buttonStyle(PlainButtonStyle())
//            }
//            .padding(.trailing, 15)
//            .padding(.leading, 10)
//            .padding(.top, 15)
//            .padding(.bottom, advertisesApp ? -10 : 0)
//            
//            Spacer()
//            
//            HStack {
//                Spacer()
//                
//                Image(connectWithApp ? .qrApp : .QR)
//                    .resizable()
//                    .aspectRatio(1, contentMode: .fit)
//                    .frame(height: 160)
//                
//                Spacer()
//               
//                
//                Text(getDescription().localized())
//                    .padding(.top, 5)
//                    .padding(.horizontal)
//                    .fixedSize(horizontal: false, vertical: true)
//                    .multilineTextAlignment(.center)
//                
//                Spacer()
//            }
//            .padding(.horizontal)
//            .padding(.bottom)
//            
//            Spacer()
//        
//        }
//        .frame(width: qrCodeViewSize.width, height: qrCodeViewSize.height)
//    }
//}
//
//#Preview {
//    QrCodeView(advertisesApp: false, closeView: {})
//}
