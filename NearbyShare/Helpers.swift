//
//  Helpers.swift
//  QuickDrop
//
//  Created by Leon Böttger on 04.04.25.
//

import Foundation

public func isPlusVersion() -> Bool {
    return UserDefaults.standard.bool(forKey: UserDefaultsKeys.plusVersion.rawValue)
}

public func isFileTransferRestricted() -> Bool {
    (!isPlusVersion() && transmissionCount() > 1)
}

public func transmissionCount() -> Int {
    return UserDefaults.standard.integer(forKey: UserDefaultsKeys.transmissionCount.rawValue)
}

public enum UserDefaultsKeys: String, CaseIterable {
    case isEligibleForIap = "isEligibleForIap"
    case appLaunchedBefore = "ShowedWelcomeScreen"
    case plusVersion = "isPlusVersion"
    case transmissionCount = "reviewRequestCountKey"
    case automaticallyAcceptFiles = "automaticallyAcceptFiles"
    case saveFolderBookmark = "saveFolderBookmark"
    case endpointID = "endpointID"
}
