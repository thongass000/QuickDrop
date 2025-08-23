//
//  TrustedDevicesView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 23.08.25.
//

import SwiftUI
#if !os(macOS)
import LUI
#endif

struct TrustedDevicesView: View {
    @StateObject private var store = TrustStore.shared
    
    @State private var deviceToRemove: String? = nil
    @State private var showRemoveAlert = false
    
    var body: some View {
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
                
                #if !os(macOS)
                CustomSection(footer: "TrustedDevicesDescription") {
                    devicesView
                        .padding(.vertical, 4)
                }
                #else
                List {
                    devicesView
                    
                    Text("TrustedDevicesDescription")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                #endif
            }
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
                        Text(cert.device.name ?? "Unknown".localized())
                            .font(.headline)
                        
                        // macOS 11: use DateFormatter instead of .formatted
                        Text(Self.dateFormatter.string(from: cert.creationDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: {
                        deviceToRemove = key
                        showRemoveAlert = true
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    
    // MARK: - DateFormatter for macOS 11
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
