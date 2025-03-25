//
//  UserDefaultKeys.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.02.25.
//

import Foundation

enum UserDefaultsKeys: String, CaseIterable {
    case isEligibleForIap = "isEligibleForIap"
    case appLaunchedBefore = "ShowedWelcomeScreen"
    case plusVersion = "isPlusVersion"
    case transmissionCount = "reviewRequestCountKey"
    case automaticallyAcceptFiles = "automaticallyAcceptFiles"
    case saveFolderBookmark = "saveFolderBookmark"
}
