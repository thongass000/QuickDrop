//
//  PurchaseHelper.swift
//  Loop
//
//  Created by Leon Böttger on 26.10.20.
//  Copyright © 2020 Leon Böttger. All rights reserved.
//

import StoreKit

let iapName = "plusversion"

class IAPManager: NSObject, ObservableObject {
    
    enum IAPManagerError: Error {
        case noProductIDsFound
        case noProductsFound
        case paymentWasCancelled
        case productRequestFailed
    }

    static let plusVersionID = iapName
    static let sharedInstance = IAPManager()
    var onReceiveProductsHandler: ((Result<[SKProduct], IAPManagerError>) -> Void)?
    var onBuyProductHandler: ((Result<Bool, Error>) -> Void)?
    var totalRestoredPurchases = 0
    var isActive = false

    private override init() {
        super.init()
        getProducts { _ in }
    }
    
    fileprivate func getProductIDs() -> [String]? {
        return [IAPManager.plusVersionID]
    }
       
    func startObserving() {
        SKPaymentQueue.default().add(self)
    }


    func stopObserving() {
        SKPaymentQueue.default().remove(self)
    }
    
    
    func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }

    func getProducts(withHandler productsReceiveHandler: @escaping (_ result: Result<[SKProduct], IAPManagerError>) -> Void) {
        // Keep the handler (closure) that will be called when requesting for
        // products on the App Store is finished.
        onReceiveProductsHandler = productsReceiveHandler

        // Get the product identifiers.
        guard let productIDs = getProductIDs() else {
            productsReceiveHandler(.failure(.noProductIDsFound))
            return
        }

        // Initialize a product request.
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))

        // Set self as the its delegate.
        request.delegate = self

        // Make the request.
        request.start()
    }

    func buy(product: SKProduct, withHandler handler: @escaping ((_ result: Result<Bool, Error>) -> Void)) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)

        // Keep the completion handler.
        onBuyProductHandler = handler
    }
    
    
    func restorePurchases(withHandler handler: @escaping ((_ result: Result<Bool, Error>) -> Void)) {
        onBuyProductHandler = handler
        totalRestoredPurchases = 0
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

extension IAPManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        log("IAP updatedTransactions")
        
        transactions.forEach { (transaction) in
            
            switch transaction.transactionState {
            case .purchased:
                log("IAP purchased")
                onBuyProductHandler?(.success(true))
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .restored:
                log("IAP restored")
                totalRestoredPurchases += 1
                onBuyProductHandler?(.success(true))
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .failed:
                log("[LUI] IAP failed")
                if let error = transaction.error as? SKError {
                    if error.code != .paymentCancelled {
                        onBuyProductHandler?(.failure(error))
                    } else {
                        onBuyProductHandler?(.failure(IAPManagerError.paymentWasCancelled))
                    }
                    log("[LUI] IAP Error:" + error.localizedDescription)
                }
                onBuyProductHandler?(.failure(transaction.error ?? IAPManagerError.productRequestFailed))
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .deferred, .purchasing: log("[LUI] other cases")
            @unknown default: log("[LUI] other default cases")
            }
        }
    }
    
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.totalRestoredPurchases == 0 {
                log("[LUI] IAP: No purchases to restore!")
                self.onBuyProductHandler?(.success(false))
            }
        }
    }
        
        
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let error = error as? SKError {
            if error.code != .paymentCancelled {
                log("[LUI] IAP Restore Error:" + error.localizedDescription)
                onBuyProductHandler?(.failure(error))
            } else {
                onBuyProductHandler?(.failure(IAPManagerError.paymentWasCancelled))
            }
        }
    }
}

extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // Get the available products contained in the response.
        let products = response.products

        // Check if there are any products available.
        if products.count > 0 {
            // Call the following handler passing the received products.
            onReceiveProductsHandler?(.success(products))
        } else {
            // No products were found.
            onReceiveProductsHandler?(.failure(.noProductsFound))
        }
    }
    
    
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return true
    }
    
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        onReceiveProductsHandler?(.failure(.productRequestFailed))
    }
    
    
    func requestDidFinish(_ request: SKRequest) {
        // Implement this method OPTIONALLY and add any custom logic
        // you want to apply when a product request is finished.
    }
}

extension IAPManager.IAPManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noProductIDsFound: return "No In-App Purchase product identifiers were found."
        case .noProductsFound: return "No In-App Purchases were found."
        case .productRequestFailed: return "plusview_productRequestFailed".localized()
        case .paymentWasCancelled: return "In-App Purchase process was cancelled."
        }
    }
}
