//
//  AppGroup.swift
//  QuickDrop
//
//  Created by Leon Böttger on 23.08.25.
//

import Foundation

/// Contains information about the app group used to share data between main app and extensions
struct AppGroup {
    
    /// Identifier of the app group
    static let appGroupName = "group.com.leonboettger.neardrop"
    static let appGroupUD = UserDefaults(suiteName: AppGroup.appGroupName)!
    
    /// Returns the shared App Group directory
    static var appGroupDirectory: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    }
}
