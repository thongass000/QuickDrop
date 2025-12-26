//
//  NoLocalNetworkAccessAlertView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.12.25.
//

import LUI
import SwiftUI

struct NoLocalNetworkAccessAlertView: View {
    var body: some View {
        CardView(backgroundColor: .red, title: "NoNetworkAccess", titleSymbol: "network.slash") {
            LUIText("NoLocalNetworkAccessDescription", color: .white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 10)
        .onTapGesture {
            #if os(iOS)
            openAppSettings()
            #endif
        }
    }
}
