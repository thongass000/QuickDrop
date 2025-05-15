//
//  NetworkFilterIssueView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.05.25.
//

import SwiftUI
import Foundation

struct NetworkFilterIssueView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        IssueView(image: .filter, header: "NetworkFilterHeader".localized(), description: "NetworkFilterDescription".localized())
    }
}


#Preview {
    NetworkFilterIssueView()
        .frame(width: issueViewWidth, height: issueViewHeight)
}

