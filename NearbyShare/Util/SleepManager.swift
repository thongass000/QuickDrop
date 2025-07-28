//
//  SleepManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 03.05.25.
//

import Foundation

#if os(macOS)
import IOKit
import IOKit.pwr_mgt
#elseif os(iOS)
import UIKit
#endif

class SleepManager {
    public static let shared = SleepManager()

    #if os(macOS)
    private var assertionID: IOPMAssertionID = 0
    #endif

    private var timer: Timer?

    private init() {
        // Start periodic check
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateSleepState()
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    private func disableSleep() {
        #if os(macOS)
        if assertionID != 0 { return }

        log("[SleepManager] Enabling Wakelock")

        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "QuickDrop Data Transfer" as CFString,
            &assertionID
        )
        #elseif os(iOS)
        log("[SleepManager] Keeping screen awake (iOS)")
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    private func enableSleep() {
        #if os(macOS)
        if assertionID == 0 { return }

        log("[SleepManager] Disabling Wakelock")

        IOPMAssertionRelease(assertionID)
        assertionID = 0
        #elseif os(iOS)
        log("[SleepManager] Allowing screen to sleep (iOS)")
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
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
