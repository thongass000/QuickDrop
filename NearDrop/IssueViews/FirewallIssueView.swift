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
        
        IssueView(image: .firewall, header: "A firewall blocks incoming file transfers", description: """
QuickDrop has detected that a firewall prevents that your Android device can connect to your Mac. Firewalls are used to block incoming connections per default. For receiving files, it is required that incoming connections are allowed. This is because your phone tries to connect to your Mac – creating an incoming connection.

You most likely use an antivirus program on your Mac. You have two options:

1.    Allow incoming connections for QuickDrop in your firewall settings. This procedure varies with every program, so you may have to ask the manufacturer of your firewall/antivirus software how this can be done.

2.    Disable the firewall of your antivirus software, and use the Mac's inbuilt firewall instead. Apple's firewall is optimized for QuickDrop. 

Here’s how to disable the firewall of your antivirus program: Open System Settings on your Mac, and navigate to Network > VPN & Filter and disable the content filter. Then, navigate to Network > Firewall and click the toggle to enable the Mac's firewall.

Once this is done, your phone will be able to connect to your Mac.
""")
    }
}


#Preview {
    FirewallIssueView()
        .frame(width: 600, height: 400)
}

