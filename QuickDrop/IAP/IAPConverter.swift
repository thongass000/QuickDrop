//
//  StoreChecker.swift
//  LUI
//
//  Created by Leon Böttger on 19.08.24.
//
import StoreKit

class IAPConverter: NSObject, SKRequestDelegate {
    
    let switchToIAPAfterAppVersion = "1.2"
    
    static let shared = IAPConverter()
    
    private override init() {
        super.init()
    }
    
    func restoreIAPfromPreviousPurchase(success: ((Bool) -> ())? = nil) {
        Task {
            do {
                // Get the appTransaction.
                
                if #available(macOS 13.0, *) {
                    let shared = try await AppTransaction.shared
                    
                    if case .verified(let appTransaction) = shared {
                        
                        let originalVersion = appTransaction.originalAppVersion
                        let newModelVersion = switchToIAPAfterAppVersion
                        log("[LUI] Original Purchased Version: \(originalVersion) | New Model Version: \(newModelVersion)")
                        
                        if originalVersion.compare(newModelVersion, options: .numeric) == .orderedAscending {
                            grant(success: success)
                            return
                        }
                    }
                } else {
                    // Fallback on earlier versions
                    // Grant IAP, as we cannot check the original purchase date.
                    DispatchQueue.main.async {
                        log("[LUI] Cannot check version - Plus Version Granted!")
                        success?(true)
                    }
                }
            }
            catch {
                // Handle errors.
                log("[LUI] Error: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                log("[LUI] Plus Version Denied!")
                success?(false)
            }
        }
    }
    
    private func grant(success: ((Bool) -> ())? = nil) {
        log("[LUI] Existing User - Plus Version Granted!")
        
        DispatchQueue.main.async {
            success?(true)
        }
    }
}
