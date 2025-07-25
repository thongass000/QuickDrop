//
//  FirewallIssueView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.05.25.
//

import SwiftUI
import Foundation

struct FirewallIssueView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        IssueView(image: .firewall, header: "FirewallHeader".localized(), description: "FirewallDescription".localized())
    }
}


#Preview {
    FirewallIssueView()
        .frame(width: issueViewWidth, height: issueViewHeight)
}

