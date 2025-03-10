//
//  Localized.swift
//  QuickDrop
//
//  Created by Leon Böttger on 10.03.25.
//

import Foundation

public extension String {
    func localized() -> String {
        let localizedString = NSLocalizedString(self, comment: "")
        return localizedString
    }
}
