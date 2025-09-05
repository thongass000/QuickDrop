//
//  Configuration.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.08.25.
//

import LUI

let configuration = LUIConfiguration(
    appName: "QuickDrop",
    
    hasRoundedFont: false,
    
    copyrightInformation: licenseText,
    
    loggingUrl: AppGroup.appGroupDirectory,
    
    introductionViewInformation: "QuickDropWelcomeDescription",
    
    usesAutomaticReviewPrompt: false,
    
    usesPagedIntroduction: false,
    
    supportsSplitView: false,
    
    supportsPortraitSplitView: false,
    
    supportsDarkModeShadow: false
)
