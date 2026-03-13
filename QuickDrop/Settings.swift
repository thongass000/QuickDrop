//
//  Settings.swift
//  QuickDrop
//
//  Created by Leon Böttger on 09.09.25.
//

import LUI
import SwiftUI

final class Settings: SharedInstance {
    
    private init() {}
    
    static var sharedInstance = Settings()
    
    
    //  MARK: - Published UserDefaults Backed Properties
    
    @Published var automaticallyAcceptFiles: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticallyAcceptFiles.rawValue)
    { didSet { UserDefaults.standard.set(automaticallyAcceptFiles, forKey: UserDefaultsKeys.automaticallyAcceptFiles.rawValue) }}

    
    @Published var openFinderAfterReceiving: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.openFinderAfterReceiving.rawValue)
    { didSet { UserDefaults.standard.set(openFinderAfterReceiving, forKey: UserDefaultsKeys.openFinderAfterReceiving.rawValue) }}

    
    @Published var saveFolderBookmark: Data? = UserDefaults.standard.data(forKey: UserDefaultsKeys.saveFolderBookmark.rawValue)
    { didSet { UserDefaults.standard.set(saveFolderBookmark, forKey: UserDefaultsKeys.saveFolderBookmark.rawValue) }}
    
    
    
    //  MARK: - Non-Published UserDefaults Backed Properties
    
    var incomingTransmissionCount: Int = UserDefaults.standard.integer(forKey: UserDefaultsKeys.transmissionCount.rawValue)
    { didSet { UserDefaults.standard.set(incomingTransmissionCount, forKey: UserDefaultsKeys.transmissionCount.rawValue) }}


    var incomingNotificationCount: Int = UserDefaults.standard.integer(forKey: UserDefaultsKeys.incomingNotificationCount.rawValue)
    { didSet { UserDefaults.standard.set(incomingNotificationCount, forKey: UserDefaultsKeys.incomingNotificationCount.rawValue) }}
    
    
    var endpointID: String? = UserDefaults.standard.string(forKey: UserDefaultsKeys.endpointID.rawValue)
    { didSet { UserDefaults.standard.set(endpointID, forKey: UserDefaultsKeys.endpointID.rawValue) }}
    
    
    var isEligibleForIap: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isEligibleForIap.rawValue)
    { didSet { UserDefaults.standard.set(isEligibleForIap, forKey: UserDefaultsKeys.isEligibleForIap.rawValue) }}
    
    
    var appLaunchedBefore: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.appLaunchedBefore.rawValue)
    { didSet { UserDefaults.standard.set(appLaunchedBefore, forKey: UserDefaultsKeys.appLaunchedBefore.rawValue) }}
    
    
    
    // MARK: - Debug
    
    func deleteAllUserDefaults() {
        let defaults = UserDefaults.standard
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
        defaults.synchronize()
        
        Settings.sharedInstance = Settings()
    }
    
    
    
    // MARK: - UserDefaults Keys
    
    public enum UserDefaultsKeys: String, CaseIterable, RawRepresentable {
        case isEligibleForIap = "isEligibleForIap"
        case appLaunchedBefore = "ShowedWelcomeScreen"
        case transmissionCount = "reviewRequestCountKey"
        case incomingNotificationCount = "incomingNotificationCount"
        case automaticallyAcceptFiles = "automaticallyAcceptFiles"
        case saveFolderBookmark = "saveFolderBookmark"
        case openFinderAfterReceiving = "openFinderAfterReceiving"
        case endpointID = "endpointID"
        
        // Plus version used before StoreKit 2 update. New key is fetched from App Store directly.
        case plusVersionLegacy = "isPlusVersion"
    }
}
