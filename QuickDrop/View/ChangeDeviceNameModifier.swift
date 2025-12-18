//
//  ChangeDeviceNameModifier.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.12.25.
//

import SwiftUI
import LUI

struct ChangeDeviceNameModifier: ViewModifier {

    let isEnabled: Bool
    private let maxLength = NearbyConnectionManager.maxNameChars

    @State private var isPresented = false
    @State private var customName = ""

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                guard isEnabled else { return }

                lightVibration()
                customName = NearbyConnectionManager.getCustomDeviceName() ?? ""
                isPresented = true
            }
            .alert("ChangeDeviceName", isPresented: $isPresented) {

                TextField("DeviceName", text: $customName)
                    .onChange(of: customName) { newValue in
                        if newValue.count > maxLength {
                            customName = String(newValue.prefix(maxLength))
                        }
                    }

                Button("Save") {
                    NearbyConnectionManager.shared
                        .setCustomDeviceName(to: customName.trimmingCharacters(in: .whitespacesAndNewlines))
                }

                Button("Cancel", role: .cancel) { }

            } message: {
                Text("ChangeDeviceNameDescription")
            }
    }
}


extension View {
    func changeDeviceNameAlert(isEnabled: Bool = true) -> some View {
        modifier(ChangeDeviceNameModifier(isEnabled: isEnabled))
    }
}
