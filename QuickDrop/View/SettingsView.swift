//
//  SettingsView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 24.03.25.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    
    @AppStorage(UserDefaultsKeys.automaticallyAcceptFiles.rawValue) private var automaticallyAcceptFiles = false
    @AppStorage(UserDefaultsKeys.openFinderAfterReceiving.rawValue) private var openFinderAfterReceiving = false
    @AppStorage(UserDefaultsKeys.saveFolderBookmark.rawValue) private var saveFolderPath: Data = Data()
    
    var body: some View {
        
        LargeAppIconView(title: "Settings") {
            Form {
                Toggle("AutomaticallyAcceptFiles", isOn: $automaticallyAcceptFiles)
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
                        .foregroundColor(saveFolderPath.isEmpty ? .gray : .primary)
                    Button("SaveFilesToButton") {
                        selectFolder()
                    }
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Toggle("OpenFinderAfterReceiving", isOn: $openFinderAfterReceiving)
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
        if !saveFolderPath.isEmpty {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: saveFolderPath, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
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
                
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                UserDefaults.standard.set(bookmarkData, forKey: UserDefaultsKeys.saveFolderBookmark.rawValue)
            } catch {
                log("Failed to save security-scoped bookmark: \(error)")
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
