//
//  SettingsView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 24.03.25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    
    @ObservedObject var settings = Settings.shared
    
    var body: some View {
        
        LargeAppIconView(title: "Settings") {
            Form {
                Toggle("AutomaticallyAcceptFiles", isOn: $settings.automaticallyAcceptFiles)
                    .padding(.top, 10)
                
                Text("AutomaticallyAcceptFilesFooter")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.top, 5)
                
                Divider()
                    .padding(.vertical, 10)
                
                HStack {
                    Text("SaveFilesTo")
                    Spacer()
                    Text(getSavedFolderPath() ?? "DownloadsFolder".localized())
                        .foregroundColor((settings.saveFolderBookmark ?? Data()).isEmpty ? .gray : .primary)
                    Button("SaveFilesToButton") {
                        selectFolder()
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Toggle("OpenFinderAfterReceiving", isOn: $settings.openFinderAfterReceiving)
                    .padding(.top, 5)
                
                if #available(macOS 13.0, *) {
                    LaunchAtLogin.Toggle {
                        Text("LaunchAtLogin")
                    }
                    .padding(.top, 5)
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Button {
                    openTrustedDevicesWindow()
                } label: {
                    Text("ManageTrustedDevices")
                        .underline()
                        .font(.subheadline)
                        .opacity(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    
    private func getSavedFolderPath() -> String? {
        if let bookmark = settings.saveFolderBookmark, !bookmark.isEmpty {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                return url.lastPathComponent  // Returns the folder path as a string
            } catch {
                log("Failed to resolve bookmark: \(error)")
            }
        }
        return nil  // No saved folder
    }
    
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "SaveFilesLocation".localized()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.urls.first {
            do {
                log("Selected folder: \(url)")
                
                if url.description == "file:///" {
                    throw NSError(domain: "InvalidSelection", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot select root directory. Please choose a specific folder."])
                }
                
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                Settings.shared.saveFolderBookmark = bookmarkData
                Settings.shared.openFinderAfterReceiving = true
            } catch {
                log("Failed to save security-scoped bookmark: \(error)")
                
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    
                    AudioManager.playErrorSound()
                    
                    // show alert
                    let alert = NSAlert()
                    alert.alertStyle = .critical
                    alert.messageText = "FolderSelectionFailedTitle".localized()
                    alert.informativeText = "FolderSelectionFailedMessage".localized()
                    alert.addButton(withTitle: "CloseAlert".localized())
                    
                    alert.runModal()
                }
            }
        }
    }
    
    
    private func openTrustedDevicesWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "TrustedDevices".localized()
        window.contentView = NSHostingView(rootView: TrustedDevicesView())
        
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.level = .normal
    }
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(width: 800, height: 500)
    }
}
