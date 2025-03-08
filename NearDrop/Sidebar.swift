//
//  Sidebar.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.03.25.
//

import SwiftUI

struct SidebarView: View {
    @State private var selection: String? = "Receive Files"
    
    var body: some View {
            HStack {
                List(selection: $selection) {
                    Label("Receive Files", systemImage: "tray.and.arrow.down.fill")
                        .tag("Receive Files")
                    Label("Send Files", systemImage: "tray.and.arrow.up.fill")
                        .tag("Send Files")
                    Label("Troubleshooting", systemImage: "exclamationmark.triangle.fill")
                        .tag("Troubleshooting")
                }
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
                .listStyle(SidebarListStyle())
                
                Divider()
                
                if let selection = selection {
                    DetailView(selection: selection)
                } else {
                    Text("Select an option").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
}

struct DetailView: View {
    let selection: String
    
    var body: some View {
        VStack {
            Text(selection)
                .font(.largeTitle)
                .bold()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


#Preview {
    SidebarView()
}
