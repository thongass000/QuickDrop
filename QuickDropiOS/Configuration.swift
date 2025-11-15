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
    
    plusVersionInfo: GetPlusViewInformation(lifetimeID: "plusversion", description: "plusview_description_phone", plusVersionFeatures: [], settingsLabelColor: .orange, settingsFooter: "plusview_footer_phone"),
    
    setPlusVersion: { result in
        DispatchQueue.main.async {
            Settings.shared.gotPlus = result
        }
    },
    
    hasRoundedFont: false,
    
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
