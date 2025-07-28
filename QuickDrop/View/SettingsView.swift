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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(width: 800, height: 500)
    }
}
