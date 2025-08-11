//
//  Model.swift
//  QuickDrop
//
//  Created by Leon Böttger on 28.07.25.
//

import SwiftUI

class ShareViewModel: ObservableObject, ShareExtensionDelegate {
    
    @Published var foundDevices: [RemoteDeviceInfo] = []
    @Published var selectedDevice: RemoteDeviceInfo?
    @Published var lastError: Error?
    
    @Published var progressState: String? = nil
    @Published var progressValue: Double? = nil
    
    private var urls: [URL] = []
    private var textToSend: String? = nil
    //private var errorAlertHandler = ErrorAlertHandler.shared
    
    private var connectionEstablished = false
    private var timeoutDispatchWorkItem: DispatchWorkItem? = nil
    
    init() {
        NearbyConnectionManager.shared.startDeviceDiscovery()
    }
    
    func addDevice(device: RemoteDeviceInfo) {
        withAnimation {
            foundDevices.append(device)
        }
    }
    
    func removeDevice(id: String) {
        withAnimation {
            foundDevices.removeAll { $0.id == id }
        }
    }
    
    func connectionWasEstablished(pinCode: String) {
        connectionEstablished = true
        progressState = String(format: "PinCode".localized(), arguments: [pinCode])
        progressValue = 0
    }
    
    func connectionFailed(with error: any Error) {
        progressValue = nil
        lastError = error
        
        //ErrorAlertHandler.shared.showErrorAlert(for: chosenDevice?.name ?? "", error: error)
    }
    
    func transferAccepted() {
        progressState = "Sending".localized()
    }
    
    func transferProgress(progress: Double) {
        progressValue = progress
    }
    
    func transferFinished() {
        progressState = "TransferFinished".localized()
    }
    
    func selectDevice(device: RemoteDeviceInfo) {
        NearbyConnectionManager.shared.stopDeviceDiscovery()
        
        progressValue = 0
        progressState = "Connecting".localized()
        selectedDevice = device
        NearbyConnectionManager.shared.startOutgoingTransfer(deviceID: device.id!, delegate: self, urls: urls, textToSend: textToSend)
    }
}
