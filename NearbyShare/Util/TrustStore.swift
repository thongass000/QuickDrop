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
        do {
            if let data = try KeychainStore.loadData(account: trustedKeysKey) {
                trustedCertificates = try JSONDecoder().decode([String: TrustedCertificate].self, from: data)
                AppGroup.appGroupUD.removeObject(forKey: trustedKeysKey)
                return
            }
        } catch {
            print("[TrustStore] Failed to load trusted certificates from keychain: \(error.localizedDescription)")
        }

        guard let dict = legacyTrustedCertificates() else {
            trustedCertificates = [:]
            return
        }
        
        trustedCertificates = dict

        do {
            try persistTrustedCertificates()
            AppGroup.appGroupUD.removeObject(forKey: trustedKeysKey)
            print("[TrustStore] Migrated trusted certificates from shared defaults to keychain.")
        } catch {
            print("[TrustStore] Failed to migrate trusted certificates to keychain: \(error.localizedDescription)")
        }
    }
    
    
    private func saveTrustedCertificates() {
        do {
            try persistTrustedCertificates()
            AppGroup.appGroupUD.removeObject(forKey: trustedKeysKey)
        } catch {
            print("[TrustStore] Failed to save trusted certificates to keychain: \(error.localizedDescription)")
        }
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


    private func persistTrustedCertificates() throws {
        let data = try JSONEncoder().encode(trustedCertificates)
        try KeychainStore.saveData(data, account: trustedKeysKey)
    }


    private func legacyTrustedCertificates() -> [String: TrustedCertificate]? {
        guard let dict = AppGroup.appGroupUD.dictionary(forKey: trustedKeysKey) as? [String: Data] else {
            return nil
        }

        var decoded: [String: TrustedCertificate] = [:]
        for (key, data) in dict {
            if let cert = try? JSONDecoder().decode(TrustedCertificate.self, from: data) {
                decoded[key] = cert
            }
        }
        return decoded
    }
}
