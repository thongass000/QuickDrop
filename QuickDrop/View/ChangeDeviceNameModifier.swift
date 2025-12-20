//
//  ChangeDeviceNameModifier.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.12.25.
//

import SwiftUI
import LUI

struct ChangeDeviceNameAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State var customName = ""
    
    let maxLength = NearbyConnectionManager.maxNameChars
    
    func body(content: Content) -> some View {
        
        content
            .alert("ChangeDeviceName", isPresented: $isPresented) {
                TextField("DeviceName", text: $customName)
                    .onChange(of: customName) { newValue in
                        if newValue.count > maxLength {
                            customName = String(newValue.prefix(maxLength))
                        }
                    }
                
                Button("Save") {
                    let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    NearbyConnectionManager.shared.setCustomDeviceName(to: trimmed)
                }
                
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("ChangeDeviceNameDescription")
            }
    }
}

extension View {
    func changeDeviceNameAlert(
        isPresented: Binding<Bool>,
    ) -> some View {
        modifier(ChangeDeviceNameAlertModifier(
            isPresented: isPresented
        ))
    }
}


struct ChangeDeviceNameModifier: ViewModifier {

    let isEnabled: Bool

    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                guard isEnabled else { return }

                lightVibration()
                isPresented = true
            }
            .changeDeviceNameAlert(isPresented: $isPresented)
    }
}



extension View {
    func changeDeviceNameAlert(isEnabled: Bool = true) -> some View {
        modifier(ChangeDeviceNameModifier(isEnabled: isEnabled))
    }
}
