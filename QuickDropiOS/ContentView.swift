//
//  ContentView.swift
//  QuickDropiOS
//
//  Created by Leon Böttger on 28.07.25.
//

import SwiftUI
import LUI

struct ContentView: View {
    
    @StateObject var model = ShareViewModel()
    
    var body: some View {
        DeviceListView(model: model)
    }
}

struct DeviceListView: View {
    
    @ObservedObject var model: ShareViewModel
    
    var body: some View {
        
        NavigationView {
            NavigationSubView(header: "QuickDrop ") {
                
                // "You're visible as"
                VStack(alignment: .leading, spacing: 8) {
                    FooterView(text: "YouAreVisibleAs")
                    
                    Text(NearbyConnectionManager.shared.getEndpointInfo().name ?? "QuickDrop")
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.defaultForegroundColor)
                        .cornerRadius(24)
                        .padding(.horizontal)
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                
                if model.foundDevices.isEmpty {
                    
                    CustomSection(header: "NoDevicesFound") {
                        
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                            
                            Text("DownloadQuickDropOnPlayStore")
                        }
                        .padding(.vertical)
                    }
                } else {
                    
                    CustomSection(header: "AvailableDevices") {
                        ForEach(model.foundDevices) { device in
                            
                            LUIButton {
                                model.selectDevice(device: device)
                            } label: {
                                HStack(spacing: 12) {
                                    
                                    let name = device.name ?? "Android"
                                    
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(red: 0.623, green: 0.659, blue: 0.855),
                                                             Color(red: 0.474, green: 0.525, blue: 0.796)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: device.icon)
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(name)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color.primary)
                                        
                                        Text(model.selectedDevice == device ? model.progressState ?? "..." : "Available".localized())
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.primary.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color.primary.opacity(0.6))
                                }
                                .padding(.vertical, 13)
                            }
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    Text("SearchingForDevices")
                        .font(.system(size: 14))
                        .foregroundColor(Color.primary.opacity(0.6))
                    
                    ProgressView()
                        .frame(width: 12, height: 12)
                }
                .padding(.vertical, 16)
                
                Spacer()
                
                // Privacy policy
                Button(action: {
                    if let url = URL(string: "https://leonboettger.com/quickdrop-privacy") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("PrivacyPolicy")
                        .font(.system(size: 14))
                        .foregroundColor(Color.accentColor.opacity(0.8))
                }
            }
        }
    }
}

extension DeviceListView {
    static var preview: DeviceListView {
        let model = ShareViewModel()
        model.foundDevices = [
            RemoteDeviceInfo(name: "MacBook Pro", type: .computer, id: "macbook-pro-id"),
            RemoteDeviceInfo(name: "iPhone 14", type: .phone, id: "iphone-14-id"),
            RemoteDeviceInfo(name: "Samsung Galaxy S21", type: .phone, id: "samsung-galaxy-s21-id")
        ]
        
        return DeviceListView(model: model)
    }
}

#Preview {
    DeviceListView.preview
}
