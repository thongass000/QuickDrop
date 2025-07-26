//
//  Helpers.swift
//  QuickDrop
//
//  Created by Leon Böttger on 04.04.25.
//

import Foundation

extension Data {
    func urlSafeBase64EncodedString() -> String {
        return String(base64EncodedString().replacingOccurrences(of: "=", with: "").map {
            if $0 == "/" {
                return "_"
            } else if $0 == "+" {
                return "-"
            } else {
                return $0
            }
        })
    }
    

    static func randomData(length: Int) -> Data {
        var data = Data(count: length)
        data.withUnsafeMutableBytes {
            guard SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) == 0 else { fatalError() }
        }
        return data
    }
    

    static func dataFromUrlSafeBase64(_ str: String) -> Data? {
        var regularB64 = String(str.map {
            if $0 == "_" {
                return "/"
            } else if $0 == "-" {
                return "+"
            } else {
                return $0
            }
        })
        while (regularB64.count % 4) != 0 {
            regularB64 = regularB64 + "="
        }
        return Data(base64Encoded: regularB64, options: .ignoreUnknownCharacters)
    }
    
    
    var hex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}


extension String {
    var dataFromHex: Data {
        var data = Data(capacity: count / 2)
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2)
            if nextIndex <= endIndex,
               let byte = UInt8(self[index ..< nextIndex], radix: 16)
            {
                data.append(byte)
            } else {
                break // or handle invalid hex gracefully
            }
            index = nextIndex
        }
        return data
    }
}


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


public func isPlusVersion() -> Bool {
    return UserDefaults.standard.bool(forKey: UserDefaultsKeys.plusVersion.rawValue)
}


public func isFileTransferRestricted() -> Bool {
    (!isPlusVersion() && transmissionCount() > 1)
}


public func transmissionCount() -> Int {
    return UserDefaults.standard.integer(forKey: UserDefaultsKeys.transmissionCount.rawValue)
}
