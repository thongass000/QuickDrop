//
//  TrustedDevicesView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 23.08.25.
//

import LUI
import SwiftUI

struct TrustedDevicesView: View {
    @StateObject private var store = TrustStore.shared
    
    @State private var deviceToRemove: String? = nil
    @State private var showRemoveAlert = false
    
    var body: some View {
        NavigationSubView(header: isMac() ? "" : "TrustedDevices") {
            VStack {
                if store.trustedCertificates.isEmpty {
                    VStack(spacing: 12) {
                        Text("NoTrustedDevices")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("TrustedDevicesDescription")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    CustomSection(footer: "TrustedDevicesDescription") {
                        devicesView
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.top, isMac() ? 18 : 0)
        }
        .animation(.default, value: store.trustedCertificates)
        .alert(isPresented: $showRemoveAlert) {
            Alert(
                title: Text("RemoveTrustedDeviceAlertTitle"),
                message: Text("RemoveTrustedDeviceAlertDescription"),
                primaryButton: .destructive(Text("Remove")) {
                    if let key = deviceToRemove {
                        store.removeTrusted(secretIdHex: key)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    
    var devicesView: some View {
        ForEach(Array(store.trustedCertificates.keys), id: \.self) { key in
            if let cert = store.trustedCertificates[key] {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        LUIText(cert.device.name ?? "Unknown".localized(), isBold: true)
                        LUIText(Self.dateFormatter.string(from: cert.creationDate), color: .mainColor.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    LUIButton {
                        deviceToRemove = key
                        showRemoveAlert = true
                    } label: {
                        ReorderListIcon(imageName: "minus.circle.fill", color: .red)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}


#Preview {
    TrustedDevicesView()
        .onAppear {
            
            var cert1 = Sharing_Nearby_PublicCertificate()
            cert1.secretID = Data([0x01, 0x02, 0x03, 0x04])
            
            TrustStore.shared.addTrusted(certificate: cert1, device: RemoteDeviceInfo(name: "MacBook Pro", type: .computer))
            
            
            var cert2 = Sharing_Nearby_PublicCertificate()
            cert2.secretID = Data([0x0A, 0x0B, 0x0C, 0x0D])
            
            TrustStore.shared.addTrusted(certificate: cert2, device: RemoteDeviceInfo(name: "iPhone", type: .phone))
            
        }
}
