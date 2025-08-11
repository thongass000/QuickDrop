//
//  ContentView.swift
//  QuickDropiOS
//
//  Created by Leon Böttger on 28.07.25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        DeviceListView()
    }
}

struct DeviceListView: View {
    @StateObject var model = ShareViewModel()

    var body: some View {
        VStack {
            Text("Available Devices")
                .font(.title)
                .padding()

            if model.foundDevices.isEmpty {
                Text("Searching for devices...")
                    .italic()
                    .padding()
            } else {
                List(model.foundDevices) { device in
                    HStack {
                        Image(systemName: "smartphone")
                            .resizable()
                            .frame(width: 30, height: 30)
                        Text(device.name.isEmpty ? "Android" : device.name)
                        Spacer()
                        
                        if model.selectedDevice == device {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                    .contentShape(Rectangle()) // Make entire row tappable
                    .onTapGesture {
                        model.selectDevice(device: device)
                    }
                    .background(model.selectedDevice == device ? Color.blue.opacity(0.2) : Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListView()
    }
}

#Preview {
    ContentView()
}
