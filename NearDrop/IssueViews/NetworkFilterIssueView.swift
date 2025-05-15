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
        
        IssueView(image: .filter, header: "A packet filter prevents file transfer", description: """
QuickDrop has detected that a program installed on your Mac modifies network traffic. As a result of that, the file you tried to send from your Android device could not be decrypted.

Your Mac may have a faulty packet filter enabled, which might be installed by your antivirus program (e.g. ESET). Open System Preferences > Network > VPN & Filter and disable the content filter.

Once this is done, you should be able to transfer files successfully.
""")
    }
}


#Preview {
    NetworkFilterIssueView()
        .frame(width: 600, height: 400)
}

