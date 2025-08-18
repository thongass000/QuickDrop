//
//  ContentView.swift
//  QuickDropiOS
//
//  Created by Leon Böttger on 28.07.25.
//

import SwiftUI
import LUI

struct ContentView: View {
    
    var body: some View {
        AppRootView(isPlus: .constant(true), phoneView: {
            DeviceListView()
                .environment(\.sheetActive, isShareExtension())
        }, settingsView: {
            CustomSection {
                LUIButton {
                    SaveFilesManager.shared.openDownloadedFilesFolder()
                } label: {
                    NavigationLinkLabel(imageName: "folder.fill", text: "BrowseDownloadedFiles")
                }
            }
        })
    }
}

struct DeviceListView: View {
    
    @StateObject var sendModel = SendModel()
    
    #if !EXTENSION
    @StateObject var receiveModel = ReceiveModel()
    #endif
    
    @ObservedObject var nearbyConnectionManager = NearbyConnectionManager.shared
    
    var body: some View {
        
        NavigationSubView(header: "QuickDrop ", navigationBarLayout: isShareExtension() ? .SmallOnlyAlways : .Default) {
            
            VStack(alignment: .leading, spacing: 8) {
                
                let attachments = nearbyConnectionManager.attachments
                
                FooterView(text: attachments == nil ? "YouAreVisibleAs".localized() : "YouAreSending".localized())
                
                HStack {
                    
                    if let image = attachments?.previewImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 10, height: 10)
                    }
                    
                    Text(attachments?.shortDescription ?? NearbyConnectionManager.shared.deviceInfo.name ?? "Unknown".localized())
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.defaultForegroundColor)
                .cornerRadius(24)
                .padding(.horizontal)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            
            if sendModel.foundDevices.isEmpty {
                
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
                    ForEach(sendModel.foundDevices) { device in
                        
                        let isSelected = sendModel.selectedDevice == device
                        
                        ZStack {
                            if let attachments = NearbyConnectionManager.shared.attachments {
                                LUIButton {
                                    sendModel.urls = attachments.urls
                                    sendModel.textToSend = attachments.textToSend
                                    sendModel.selectDevice(device: device)
                                } label: {
                                    DeviceButton(device: device, isSelected: isSelected, progress: sendModel.progressState, progressValue: sendModel.progressValue)
                                }
                            }
                            else {
                                SendPickerButton {
                                    DeviceButton(device: device, isSelected: isSelected, progress: sendModel.progressState, progressValue: sendModel.progressValue)
                                } onResult: { urls, text in
                                    sendModel.urls = urls ?? []
                                    sendModel.textToSend = text
                                    sendModel.selectDevice(device: device)
                                }
                            }
                        }
                        .animation(.easeInOut, value: sendModel.progressValue)
                        .animation(.easeInOut, value: isSelected)
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
        }
        .navigationBarItems(trailing: ZStack {
            if isShareExtension() {
                XButton(action: { NearbyConnectionManager.shared.attachments?.closeView?() })
            }
            else {
                LUISettingsButton()
            }
        })
    }
}


struct DeviceButton: View {
    
    let device: RemoteDeviceInfo
    let isSelected: Bool
    let progress: String?
    let progressValue: Double?
    
    var body: some View {
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
                
                Text(isSelected ? progress ?? "..." : "Available".localized())
                    .font(.system(size: 12))
                    .foregroundColor(Color.primary.opacity(0.6))
            }
            
            Spacer()
            
            if isSelected, let progress = progressValue {
                PieProgressView(progress: progress, size: 20)
            }
            else {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.primary.opacity(0.6))
            }
        }
        .padding(.vertical, 13)
    }
}


func isShareExtension() -> Bool {
    #if EXTENSION
    return true
    #else
    return false
    #endif
}


//extension DeviceListView {
//    static var preview: DeviceListView {
//        let model = SendModel()
//        model.foundDevices = [
//            RemoteDeviceInfo(name: "MacBook Pro", type: .computer, id: "macbook-pro-id"),
//            RemoteDeviceInfo(name: "iPhone 14", type: .phone, id: "iphone-14-id"),
//            RemoteDeviceInfo(name: "Samsung Galaxy S21", type: .phone, id: "samsung-galaxy-s21-id")
//        ]
//        
//        return DeviceListView(sendModel: model, receiveModel: ReceiveModel())
//    }
//}
//
//#Preview {
//    NavigationView {
//        DeviceListView.preview
//    }
//}
