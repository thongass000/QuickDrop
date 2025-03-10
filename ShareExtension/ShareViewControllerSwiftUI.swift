////
////  ShareViewControllerSwiftUI.swift
////  QuickDrop
////
////  Created by Leon Böttger on 10.03.25.
////
//
//import SwiftUI
//import NearbyShare
//
//import SwiftUI
//import Cocoa
//
//class ShareViewController: NSViewController {
//    private let viewModel = ShareViewModel()
//    
//    override func loadView() {
//        self.view = NSHostingView(rootView: ShareView(viewModel: viewModel))
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        NearbyConnectionManager.shared.startDeviceDiscovery()
//        NearbyConnectionManager.shared.addShareExtensionDelegate(viewModel)
//    }
//    
//    override func viewWillDisappear() {
//        NearbyConnectionManager.shared.stopDeviceDiscovery()
//        NearbyConnectionManager.shared.removeShareExtensionDelegate(viewModel)
//    }
//}
//
//import SwiftUI
//import Combine
//import NearbyShare
//
//class ShareViewModel: ObservableObject, ShareExtensionDelegate {
//    @Published var foundDevices: [RemoteDeviceInfo] = []
//    @Published var transferProgress: Double = 0.0
//    @Published var transferState: String = "Idle"
//    @Published var chosenDevice: RemoteDeviceInfo?
//
//    func addDevice(device: RemoteDeviceInfo) {
//        DispatchQueue.main.async {
//            self.foundDevices.append(device)
//        }
//    }
//
//    func removeDevice(id: String) {
//        DispatchQueue.main.async {
//            self.foundDevices.removeAll { $0.id == id }
//        }
//    }
//
//    func connectionWasEstablished(pinCode: String) {
//        DispatchQueue.main.async {
//            self.transferState = "Connected - PIN: \(pinCode)"
//            self.transferProgress = 0.0
//        }
//    }
//
//    func connectionFailed(with error: Error) {
//        DispatchQueue.main.async {
//            self.transferState = "Error: \(error.localizedDescription)"
//        }
//    }
//
//    func transferAccepted() {
//        DispatchQueue.main.async {
//            self.transferState = "Sending..."
//        }
//    }
//
//    func transferProgress(progress: Double) {
//        DispatchQueue.main.async {
//            self.transferProgress = progress
//        }
//    }
//
//    func transferFinished() {
//        DispatchQueue.main.async {
//            self.transferState = "Transfer finished"
//        }
//    }
//
//    func selectDevice(device: RemoteDeviceInfo) {
//        DispatchQueue.main.async {
//            self.chosenDevice = device
//            self.transferState = "Connecting to \(device.name)..."
//        }
//        NearbyConnectionManager.shared.stopDeviceDiscovery()
//        NearbyConnectionManager.shared.startOutgoingTransfer(deviceID: device.id!, delegate: self, urls: [])
//    }
//}
//
//
//import SwiftUI
//
//struct ShareView: View {
//    @ObservedObject var viewModel: ShareViewModel
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Nearby Devices")
//                .font(.title)
//
//            List(viewModel.foundDevices, id: \.id) { device in
//                Button(action: {
//                    viewModel.selectDevice(device: device)
//                }) {
//                    HStack {
//                        Image(systemName: deviceImageName(for: device.type))
//                        Text(device.name)
//                    }
//                }
//            }
//            
//            Text(viewModel.transferState)
//                .padding()
//
//            ProgressView(value: viewModel.transferProgress, total: 1000)
//                .progressViewStyle(LinearProgressViewStyle())
//                .padding()
//        }
//        .padding()
//    }
//
//    private func deviceImageName(for type: RemoteDeviceInfo.DeviceType) -> String {
//        switch type {
//        case .tablet:
//            return "ipad"
//        case .computer:
//            return "desktopcomputer"
//        default:
//            return "iphone"
//        }
//    }
//}
