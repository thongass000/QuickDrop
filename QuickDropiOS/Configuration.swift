//
//  Configuration.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.08.25.
//

import LUI

let configuration = LUIConfiguration(
    appName: "QuickDrop",
    
    inAppPurchaseName: "plusversion",
    
    plusVersionInfo: GetPlusViewInformation(description: "plusview_description_phone", plusVersionFeatures: [], settingsLabelColor: .orange, settingsFooter: "plusview_footer_phone"),
    
    hasRoundedFont: false,
    
    copyrightInformation: licenseText,
    
    loggingUrl: AppGroup.appGroupDirectory,
    
    introductionViewInformation: "QuickDropWelcomeDescription",
    
    usesAutomaticReviewPrompt: false,
    
    usesPagedIntroduction: false,
    
    supportsSplitView: false,
    
    supportsLiquidGlass: true,
    
    supportsPortraitSplitView: false,
    
    supportsDarkModeShadow: false
)
