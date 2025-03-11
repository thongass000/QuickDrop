//
//  QrCodeVIew.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.03.25.
//

import SwiftUI

let qrCodeViewSize = CGSize(width: 600.0, height: 300.0)

struct QrCodeView: View {
    @State private var qrCode: String = ""
    
    var body: some View {
        VStack {
            
            Spacer()
            
            HStack {
                Spacer()
                
                Image("QR")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(height: 230)
                
                Spacer()
                
                Text("QrCodeInstructions".localized())
                    .padding(.top)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: qrCodeViewSize.width, height: qrCodeViewSize.height)
    }
}


#Preview {
    QrCodeView()
}
