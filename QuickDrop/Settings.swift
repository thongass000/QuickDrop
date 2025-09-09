//
//  Settings.swift
//  QuickDrop
//
//  Created by Leon Böttger on 09.09.25.
//

import SwiftUI

class Settings: ObservableObject {
    
    private init() {}
    
    static var shared = Settings()
    
    
    //  MARK: - Published UserDefaults Backed Properties
    
    @Published var isPlusVersion = UserDefaults.standard.bool(forKey: UserDefaultsKeys.plusVersion.rawValue)
    { didSet { UserDefaults.standard.set(isPlusVersion, forKey: UserDefaultsKeys.plusVersion.rawValue) }}
    
    
    @Published var automaticallyAcceptFiles: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticallyAcceptFiles.rawValue)
    { didSet { UserDefaults.standard.set(automaticallyAcceptFiles, forKey: UserDefaultsKeys.automaticallyAcceptFiles.rawValue) }}

    
    @Published var openFinderAfterReceiving: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.openFinderAfterReceiving.rawValue)
    { didSet { UserDefaults.standard.set(openFinderAfterReceiving, forKey: UserDefaultsKeys.openFinderAfterReceiving.rawValue) }}

    
    @Published var saveFolderBookmark: Data? = UserDefaults.standard.data(forKey: UserDefaultsKeys.saveFolderBookmark.rawValue)
    { didSet { UserDefaults.standard.set(saveFolderBookmark, forKey: UserDefaultsKeys.saveFolderBookmark.rawValue) }}
    
    
    
    //  MARK: - Non-Published UserDefaults Backed Properties
    
    var incomingTransmissionCount: Int = UserDefaults.standard.integer(forKey: UserDefaultsKeys.transmissionCount.rawValue)
    { didSet { UserDefaults.standard.set(incomingTransmissionCount, forKey: UserDefaultsKeys.transmissionCount.rawValue) }}
    
    
    var endpointID: String? = UserDefaults.standard.string(forKey: UserDefaultsKeys.endpointID.rawValue)
    { didSet { UserDefaults.standard.set(endpointID, forKey: UserDefaultsKeys.endpointID.rawValue) }}
    
    
    var isEligibleForIap: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isEligibleForIap.rawValue)
    { didSet { UserDefaults.standard.set(isEligibleForIap, forKey: UserDefaultsKeys.isEligibleForIap.rawValue) }}
    
    
    var appLaunchedBefore: Bool = UserDefaults.standard.bool(forKey: UserDefaultsKeys.appLaunchedBefore.rawValue)
    { didSet { UserDefaults.standard.set(appLaunchedBefore, forKey: UserDefaultsKeys.appLaunchedBefore.rawValue) }}
    
    
    
    // MARK: - Debug
    
    func deleteAllUserDefaults() {
        for key in UserDefaultsKeys.allCases {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
        
        Settings.shared = Settings()
    }
    
    
    
    // MARK: - UserDefaults Keys
    
    public enum UserDefaultsKeys: String, CaseIterable {
        case isEligibleForIap = "isEligibleForIap"
        case appLaunchedBefore = "ShowedWelcomeScreen"
        case plusVersion = "isPlusVersion"
        case transmissionCount = "reviewRequestCountKey"
        case automaticallyAcceptFiles = "automaticallyAcceptFiles"
        case saveFolderBookmark = "saveFolderBookmark"
        case openFinderAfterReceiving = "openFinderAfterReceiving"
        case endpointID = "endpointID"
    }
}
