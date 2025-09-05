//
//  TrustStore.swift
//  QuickDrop
//
//  Created by Leon Böttger on 22.08.25.
//


import Foundation


class TrustStore: ObservableObject {
    
    static let shared = TrustStore()
    
    @Published private(set) var trustedCertificates: [String: TrustedCertificate] = [:]
    
    private let trustedKeysKey = "com.leonboettger.quickdrop.identity.trustedKeys"
        
    private init() {
        loadTrustedCertificates()
    }
    
    
    // MARK: - Persistence
    
    private func loadTrustedCertificates() {
        guard let dict = AppGroup.appGroupUD.dictionary(forKey: trustedKeysKey) as? [String: Data] else {
            trustedCertificates = [:]
            return
        }
        
        var decoded: [String: TrustedCertificate] = [:]
        for (key, data) in dict {
            if let cert = try? JSONDecoder().decode(TrustedCertificate.self, from: data) {
                decoded[key] = cert
            }
        }
        trustedCertificates = decoded
    }
    
    
    private func saveTrustedCertificates() {
        var dict: [String: Data] = [:]
        for (key, cert) in trustedCertificates {
            if let data = try? JSONEncoder().encode(cert) {
                dict[key] = data
            }
        }
        AppGroup.appGroupUD.set(dict, forKey: trustedKeysKey)
    }
    
    
    // MARK: - Public API
    
    func findTrustedKey(for secretIdHash: Data) -> Data? {
        trustedCertificates[secretIdHash.hex]?.certificateData
    }
    
    
    func addTrusted(certificate: Sharing_Nearby_PublicCertificate, device: RemoteDeviceInfo) {
        guard let publicKeyData = try? certificate.serializedData() else { return }
        
        trustedCertificates[certificate.secretID.hex] = TrustedCertificate(
            device: device,
            creationDate: Date(),
            certificateData: publicKeyData
        )
        
        saveTrustedCertificates()
    }
    
    
    func removeTrusted(secretIdHex: String) {
        trustedCertificates.removeValue(forKey: secretIdHex)
        saveTrustedCertificates()
    }
    
    
    struct TrustedCertificate: Codable, Equatable {
        
        // warning: do not rename for persistence
        let device: RemoteDeviceInfo
        let creationDate: Date
        let certificateData: Data
    }
}
