//
//  DistributionDetector.swift
//  QuickDrop
//
//  Created by Leon Böttger on 11.08.25.
//

import Security
import Foundation

class DistributionDetector {
    
    static var isDirectDistributionEnabled: Bool {
        get {
            if let cached = _directDistributionCached {
                return cached
            }
            
            let result = isDirectDistribution()
            self._directDistributionCached = result
            log("[DistributionDetector] isDirectDistribution: \(result)")
            
            return result
        }
    }
    
    
    static var _directDistributionCached: Bool? = nil
    
    
    private static func isDirectDistribution() -> Bool {
        // 1. Get dynamic code object for our process
        var code: SecCode?
        var status = SecCodeCopySelf([], &code)
        guard status == errSecSuccess, let codeRef = code else {
            log("[DistributionDetector] Could not get code object)")
            return false
        }
        
        // 2. Convert to static code object
        var staticCode: SecStaticCode?
        status = SecCodeCopyStaticCode(codeRef, [], &staticCode)
        guard status == errSecSuccess, let staticCodeRef = staticCode else {
            log("[DistributionDetector] Could not get static code object)")
            return false
        }
        
        // 3. Get signing info
        var infoCF: CFDictionary?
        status = SecCodeCopySigningInformation(staticCodeRef,
                                               SecCSFlags(rawValue: kSecCSSigningInformation),
                                               &infoCF)
        guard status == errSecSuccess, let info = infoCF as? [String: Any] else {
            log("[DistributionDetector] Could not get signing info")
            return false
        }
        
        // 4. Look at the first certificate's common name
        if let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let firstCert = certificates.first {
            var commonName: CFString?
            status = SecCertificateCopyCommonName(firstCert, &commonName)
            if status == errSecSuccess, let commonNameStr = commonName as String? {
                if commonNameStr.contains("Developer ID Application") {
                    return true
                }
            }
        }
        
        return false
    }
}
