//
//  Configuration.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.08.25.
//

import LUI
import Foundation

let configuration = LUIConfiguration(
    appName: "QuickDrop",
    
    plusVersionInfo: GetPlusViewInformation(lifetimeID: "plusversion", monthlyID: "quickdrop.monthly", yearlyID: "quickdrop.yearly", plusViewHeader: isMac() ? "plusview_title" : nil, description: isMac() ? "plusview_description" : "plusview_description_phone", onBoughtPlusVersionAlertMessage: "plusview_success_description", plusVersionFeatures: [], settingsLabelColor: .orange, settingsFooter: "plusview_footer_phone"),
    
    setPlusVersion: { result in
        DispatchQueue.main.async {
            Settings.shared.gotPlus = result
        }
    },
    
    hasRoundedFont: false,
    
    switchedToIAPafterBundleVersion: AppVersionBundle(appVersion: "1.2", buildVersion: 0, legacyUserDefaultsKey: Settings.UserDefaultsKeys.plusVersionLegacy.rawValue),
    
    copyrightInformation: licenseText,
    
    loggingUrl: AppGroup.appGroupDirectory,
    
    introductionViewInformation: "QuickDropWelcomeDescription",
    
    usesAutomaticReviewPrompt: false,
    
    usesPagedIntroduction: true,
    
    supportsSplitView: false,
    
    supportsLiquidGlass: true,
    
    supportsPortraitSplitView: false,
    
    supportsDarkModeShadow: false
)
