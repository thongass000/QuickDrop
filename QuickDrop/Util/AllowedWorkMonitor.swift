//
//  AllowedWorkMonitor.swift
//  QuickDrop
//
//  Created by Leon Böttger on 26.12.25.
//


import AppKit
import CoreGraphics
import LUI

final class AllowedWorkMonitor {
    var onAllowed: (() -> Void)?
    var onStopped: (() -> Void)?

    private var screenOn = true
    private var sessionActive = true
    private var lastAllowed: Bool?

    private var observerTokens: [NSObjectProtocol] = []

    
    func start() {
        stop()

        let nc = NSWorkspace.shared.notificationCenter

        observerTokens.append(nc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            log("[AllowedWorkMonitor] Screen did sleep")
            self?.screenOn = false
            self?.evaluateAndNotify()
        })

        observerTokens.append(nc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            log("[AllowedWorkMonitor] Screen did wake")
            self?.screenOn = true
            self?.evaluateAndNotify()
        })

        observerTokens.append(nc.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            log("[AllowedWorkMonitor] Session did resign active")
            self?.sessionActive = false
            self?.evaluateAndNotify()
        })

        observerTokens.append(nc.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            log("[AllowedWorkMonitor] Session did become active")
            self?.sessionActive = true
            self?.evaluateAndNotify()
        })

        // Initial fire to establish state
        evaluateAndNotify(forceNotify: true)
    }
    

    func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        observerTokens.forEach { nc.removeObserver($0) }
        observerTokens.removeAll()
        lastAllowed = nil
    }

    
    deinit { stop() }

    
    private func computeAllowed() -> Bool {
        return screenOn && sessionActive
    }
    
    
    private func evaluateAndNotify(forceNotify: Bool = false) {
        let allowed = computeAllowed()

        if forceNotify || lastAllowed == nil {
            lastAllowed = allowed
            allowed ? onAllowed?() : onStopped?()
            return
        }

        guard allowed != lastAllowed else { return }
        lastAllowed = allowed
        allowed ? onAllowed?() : onStopped?()
    }
}
