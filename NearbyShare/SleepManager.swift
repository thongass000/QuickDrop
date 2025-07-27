//
//  SleepManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 03.05.25.
//

import Foundation
import IOKit
import IOKit.pwr_mgt

class SleepManager {
    public static let shared = SleepManager()
    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    private init() {
        // Start periodic check
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateSleepState()
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    private func disableSleep() {
        if assertionID != 0 {
            return
        }

        log("[SleepManager] Enabling Wakelock")
        
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "QuickDrop Data Transfer" as CFString,
            &assertionID
        )
    }

    private func enableSleep() {
        if assertionID == 0 {
            return
        }

        log("[SleepManager] Disabling Wakelock")
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    private func updateSleepState() {
        let activeConnections = NearbyConnectionManager.shared.getActiveConnectionsCount()
        if activeConnections > 0 {
            disableSleep()
        } else {
            enableSleep()
        }
    }
}
