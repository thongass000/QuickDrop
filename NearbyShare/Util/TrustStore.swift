//
//  TrustStore.swift
//  QuickDrop
//
//  Created by Leon Böttger on 22.08.25.
//


import Foundation

class TrustStore {
    
    static let shared = TrustStore()
    private let trustedKeysKey = "com.leonboettger.quickdrop.identity.trustedKeys"

    
    private func getTrustedKeys() -> [String: Data] {
        return AppGroup.appGroupUD.dictionary(forKey: trustedKeysKey) as? [String: Data] ?? [:]
    }
    

    func findTrustedKey(for secretIdHash: Data) -> Data? {
        return getTrustedKeys()[secretIdHash.hex]
    }
    

    func addTrusted(certificate: Sharing_Nearby_PublicCertificate) {
        guard let publicKeyData = try? certificate.serializedData() else { return }
        var keys = getTrustedKeys()
        keys[certificate.secretID.hex] = publicKeyData
        AppGroup.appGroupUD.set(keys, forKey: trustedKeysKey)
    }
}
