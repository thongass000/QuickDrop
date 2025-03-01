//
//  GetPlusView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 23.02.25.
//

import SwiftUI
import StoreKit

struct GetPlusView: View {
    
    @AppStorage(UserDefaultsKeys.plusVersion.rawValue) var isPlusVersion = false
    @ObservedObject private var iaphelper = IAPManager.sharedInstance
    let closeView: () -> Void
    
    @State private var restoring = false
    @State private var showRestoreError = false
    @State private var restoreError = ""
    
    @Environment(\.colorScheme) var colorScheme
    @State var products = [SKProduct]()
    @State var price: String = ""
    @State var warning = false
    @State var buying = false
    @State var errorText = ""
    
    @State var boughtSuccessAlert = false
    
    
    var body: some View {
        
        ZStack {
            Color.defaultBackground
                .edgesIgnoringSafeArea(.all)
            
            let validPrice = price != ""
            
            VStack(spacing: 12) {
                Text("plusview_title")
                    .font(.title)
                    .bold()
                
                Text("plusview_description")
                    .multilineTextAlignment(.center)
                    .padding()
                    .padding(.top, -10)
                    .alert(isPresented: $boughtSuccessAlert, content: {
                        Alert(title: Text("plusview_success_title"), message: Text("plusview_success_description"), dismissButton: .default(Text("plusview_success_button"), action: {
                            closeView()
                        }))
                    })
                
                HStack(spacing: 10) {
                    Button("plusview_restorepurchase") {
                        restorePurchases()
                    }
                    .keyboardShortcut(.cancelAction)
                    .alert(isPresented: $showRestoreError, content: {
                        Alert(title: Text("plusview_restorefailed"), message: Text(restoreError), dismissButton: .default(Text("plusview_restorefailed_proceed")))
                    })
                    .opacity(restoring ? 0 : 1)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                            .opacity(restoring ? 1 : 0)
                    )
                    
                    let priceString = validPrice ? " (\(price))" : ""
                    
                    Button("plusview_unlock_label".localized() + priceString) {
                        buttonAction()
                    }
                    .keyboardShortcut(.defaultAction)
                    .alert(isPresented: $warning, content: {
                        Alert(title: Text("plusview_purchasefailed"), message: Text("plusview_purchasefaileddescription".localized() + (errorText != "" ? " Error: " : "") + errorText), dismissButton: .default(Text("plusview_restorefailed_proceed")))
                    })
                }
                .opacity(buying || restoring ? 0 : 1)
                .overlay(
                    ProgressView()
                        .scaleEffect(0.5)
                        .opacity(buying || restoring ? 1 : 0)
                )
            }
            .onAppear {
                loadProducts(shouldBuy: false)
            }
            .animation(.default, value: validPrice)
            .padding()
        }
        .frame(width: 400, height: 200)
    }

    
    func restorePurchases() {
        
        withAnimation {
            restoring = true
        }
        
        iaphelper.restorePurchases { result in
            DispatchQueue.main.async {
                
                switch result {
                case .success(let success):
                    if success {
                        withAnimation {
                            isPlusVersion = true
                        }
                        boughtSuccessAlert = true
                    } else {
                        //nothing to restore
                        restoreFailed(message: "plusview_nothingtorestore")
                    }
                    
                case .failure(let error):
                    log(error.localizedDescription)
                    restoreFailed(message: error.localizedDescription)
                }
            }
        }
        
        func restoreFailed(message: String) {
            
            #if targetEnvironment(simulator)
            isPlusVersion = true
            dismissView()
            #else
            
            // now, try to convert from old version
            IAPConverter.shared.restoreIAPfromPreviousPurchase { success in
                
                DispatchQueue.main.async {
                    
                    if success {
                        withAnimation {
                            isPlusVersion = true
                        }
                        
                        boughtSuccessAlert = true
                    }
                    else {
                        restoreError = message
                        showRestoreError = true
                        
                        withAnimation {
                            restoring = false
                        }
                    }
                }
            }
            #endif
        }
    }
    
    func buttonAction() {
        if let product = products.first {
            purchase(product: product)
        }
        else {
            loadProducts(shouldBuy: true)
        }
    }
    
    
    func purchase(product: SKProduct) {
        if !iaphelper.canMakePayments() {
            warning = true
        } else {
            withAnimation{
                buying = true
            }
            
            iaphelper.buy(product: product) { (result) in
                DispatchQueue.main.async {
                    withAnimation{
                        buying = false
                    }
                    
                    switch result {
                    case .success(_):
                        
                        withAnimation {
                            isPlusVersion = true
                            boughtSuccessAlert = true
                            warning = false
                        }
                        
                    case .failure(let error):
                        warning = true
                        errorText = error.localizedDescription
                    }
                }
            }
        }
    }
    
    func loadProducts(shouldBuy: Bool) {
        iaphelper.getProducts { (result) in
            DispatchQueue.main.async {
                
                switch result {
                case .success(let products):
                    self.products = products
                    price = products.first?.localizedPrice ?? ""
                    
                    if let product = products.first, shouldBuy {
                        purchase(product: product)
                    }
                    
                case .failure(let error):
                    errorText = error.localizedDescription
                    
                    if(shouldBuy){
                        warning = true
                    }
                    
                    withAnimation{
                        buying = false
                    }
                }
            }
        }
    }
}


extension SKProduct {
    var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        if let price = formatter.string(from: price) {
            return price
        }
        return ""
    }
}



#Preview {
    GetPlusView(closeView: {})
}
