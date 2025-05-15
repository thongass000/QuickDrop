//
//  ApIsolationIssueView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.05.25.
//

import SwiftUI
import Foundation
import AppKit
import Network

struct ApIsolationIssueView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        
        IssueView(image: .router, header: "Your router doesn't allow device-to-device communication", description: """
QuickDrop has detected that your Wi-Fi router might block devices from talking to each other. To transfer files between your phone and your Mac, you’ll need to disable client isolation (also known as AP isolation or Wi-Fi isolation).

Here’s how to disable it:

1.    Log into your router: Open a web browser and enter your router’s IP address (usually 192.168.0.1 or 192.168.1.1), or use the button on the bottom of this page. Log in with your admin username and password. (Check your router label or manual if you’re unsure.)

2.    Find the setting: Look under sections like Wireless Settings, Advanced Settings, or Security. Look for options named “AP Isolation”, “Client Isolation”, “Wireless Isolation”, or “Intra-BSS Blocking”.

3.    Disable it: Make sure this setting is turned off. Save your changes and reboot the router if necessary.

Once disabled, devices on your Wi-Fi (like your phone and Mac) will be able to discover and connect to each other.
""", actionLabel: "Open Router Settings") {
            openRouterSettingsPage()
        }
    }
}


func openRouterSettingsPage() {
    guard let routerIP = getDefaultGatewayIP() else {
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            
            alert.messageText = "Could not find router IP"
            alert.informativeText = "QuickDrop was not able to determine the address of your router. Please refer to the user manual of your Wi-Fi router to obtain its address."
            
            alert.addButton(withTitle: "CloseAlert".localized())

            let _ = alert.runModal()
        }

        return
    }

    if let url = URL(string: "http://\(routerIP)") {
        NSWorkspace.shared.open(url)
    }
}
/// Attempts to get the default gateway IP address (e.g., 192.168.1.1)
/// and ensures it's reachable. Returns nil if unreachable or not found.
func getDefaultGatewayIP() -> String? {
    let output = shell("netstat -rn | grep default")
    let lines = output.components(separatedBy: .newlines)

    for line in lines {
        let components = line.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if components.count >= 2 {
            let gateway = components[1]
            if isHostReachable(gateway) {
                return gateway
            } else {
                print("Gateway \(gateway) not reachable.")
                return nil
            }
        }
    }
    return nil
}

/// Executes a shell command and returns the output
@discardableResult
func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

/// Checks if a host (IP address or hostname) is reachable on port 80
func isHostReachable(_ host: String) -> Bool {
    let semaphore = DispatchSemaphore(value: 0)
    var reachable = false

    let hostEndpoint = NWEndpoint.Host(host)
    let port: NWEndpoint.Port = 80

    let connection = NWConnection(host: hostEndpoint, port: port, using: .tcp)

    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            reachable = true
            connection.cancel()
            semaphore.signal()
        case .failed(_), .cancelled:
            connection.cancel()
            semaphore.signal()
        default:
            break
        }
    }

    connection.start(queue: .global())
    _ = semaphore.wait(timeout: .now() + 3)  // wait max 3 seconds

    return reachable
}



#Preview {
    ApIsolationIssueView()
        .frame(width: issueViewWidth, height: issueViewHeight)
}

