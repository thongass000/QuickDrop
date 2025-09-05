//
//  License.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.08.25.
//

import Foundation

var licenseText: String {
    if let path = Bundle.main.path(forResource: "License", ofType: "txt"),
       let licenseText = try? String(contentsOfFile: path) {
        return licenseText
    }
    else {
        return Bundle.main.path(forResource: "License", ofType: "txt") ?? "License file not found"
    }
}
