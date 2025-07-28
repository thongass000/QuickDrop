//
//  ConnectionFailureTracker.swift
//  QuickDrop
//
//  Created by Leon Böttger on 15.05.25.
//

import Foundation

class ConnectionFailureTracker {
    static let shared = ConnectionFailureTracker()

    private var failureTimestamps: [Date] = []
    private var lastAlertShownAt: Date?

    private let queue = DispatchQueue(label: "ConnectionFailureTrackerQueue")

    private init() {}

    func recordFailure(onTrigger: @escaping () -> Void) {
        queue.async {
            let now = Date()

            // Remove old timestamps older than 10 seconds
            self.failureTimestamps = self.failureTimestamps.filter { now.timeIntervalSince($0) < 10 }
            self.failureTimestamps.append(now)

            // Check if alert can be shown
            let canShowAlert = self.failureTimestamps.count >= 2 &&
                               (self.lastAlertShownAt == nil || now.timeIntervalSince(self.lastAlertShownAt!) >= 60)

            if canShowAlert {
                self.lastAlertShownAt = now
                self.failureTimestamps.removeAll()
                DispatchQueue.main.async {
                    onTrigger()
                }
            }
        }
    }
}
