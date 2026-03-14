//
//  TrustStore.swift
//  QuickDrop
//
//  Created by Leon Böttger on 22.08.25.
//

import Foundation
import CryptoKit

class TrustStore: ObservableObject {
    
    static let shared = TrustStore()
    
    @Published private(set) var trustedCertificates: [String: TrustedCertificate] = [:]
    
    private let trustedKeysKey = "com.leonboettger.quickdrop.identity.trustedKeys"
    private let pendingNotificationSyncQueue = DispatchQueue(label: "TrustStore.notificationSyncPending")
    private var pendingNotificationSyncTrust: [String: PendingNotificationSyncTrust] = [:]
    private let pendingNotificationSyncTTL: TimeInterval = 5 * 60
        
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


    // MARK: - Notification Sync Pending Trust

    func registerPendingNotificationSyncTrust(secretIdHex: String, pinCode: String) {
        let normalized = secretIdHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPin = pinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !trimmedPin.isEmpty else { return }

        let pinHash = Self.pinHash(for: trimmedPin)
        pendingNotificationSyncQueue.sync {
            pendingNotificationSyncTrust[normalized] = PendingNotificationSyncTrust(
                pinHash: pinHash,
                createdAt: Date()
            )
        }
    }

    func confirmPendingNotificationSyncTrust(secretIdHex: String, pinHash: Data) -> Bool {
        let normalized = secretIdHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !pinHash.isEmpty else { return false }

        let now = Date()
        return pendingNotificationSyncQueue.sync {
            guard let pending = pendingNotificationSyncTrust[normalized] else { return false }
            pendingNotificationSyncTrust.removeValue(forKey: normalized)
            let expired = now.timeIntervalSince(pending.createdAt) > pendingNotificationSyncTTL
            if expired {
                return false
            }
            return pending.pinHash == pinHash
        }
    }

    func clearPendingNotificationSyncTrust(secretIdHex: String) {
        let normalized = secretIdHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }

        _ = pendingNotificationSyncQueue.sync {
            pendingNotificationSyncTrust.removeValue(forKey: normalized)
        }
    }
    
    
    struct TrustedCertificate: Codable, Equatable {
        
        // warning: do not rename for persistence
        let device: RemoteDeviceInfo
        let creationDate: Date
        let certificateData: Data
    }

    struct PendingNotificationSyncTrust: Equatable {
        let pinHash: Data
        let createdAt: Date
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

    private static func pinHash(for pinCode: String) -> Data {
        let data = Data(pinCode.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
}
