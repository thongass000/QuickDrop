//
//  MirroredNotificationSupport.swift
//  QuickDrop
//

import Foundation
import CryptoKit
import UserNotifications
import LUI

enum MirroredNotificationProtocol {
    static let introductionTitle = "__quickdrop_mirror_notification_v1__"
}

final class MirroredNotificationPresenter {

    static let shared = MirroredNotificationPresenter()

    private let center = UNUserNotificationCenter.current()
    private let queue = DispatchQueue(label: "MirroredNotificationPresenter")
    private var pendingNotifications: [(MirroredNotificationEnvelope, String?)] = []
    private var authorizationRequestInFlight = false

    private init() {}

    func present(rawPayload: String, senderDeviceName: String?) {
        guard let envelope = decodeEnvelope(from: rawPayload) else {
            log("[MirroredNotificationPresenter] Failed to decode mirrored notification payload")
            return
        }

        queue.async {
            self.postNotificationIfAuthorized(envelope: envelope, senderDeviceName: senderDeviceName)
        }
    }

    private func decodeEnvelope(from rawPayload: String) -> MirroredNotificationEnvelope? {
        guard let data = rawPayload.data(using: .utf8) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(MirroredNotificationEnvelope.self, from: data)
        } catch {
            log("[MirroredNotificationPresenter] Failed to decode envelope JSON: \(error.localizedDescription)")
            return nil
        }
    }

    private func postNotificationIfAuthorized(envelope: MirroredNotificationEnvelope, senderDeviceName: String?) {
        center.getNotificationSettings { settings in
            self.queue.async {
                self.handleAuthorizationStatus(
                    settings.authorizationStatus,
                    envelope: envelope,
                    senderDeviceName: senderDeviceName
                )
            }
        }
    }

    private func handleAuthorizationStatus(
        _ status: UNAuthorizationStatus,
        envelope: MirroredNotificationEnvelope,
        senderDeviceName: String?
    ) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            post(envelope: envelope, senderDeviceName: senderDeviceName)
        case .notDetermined:
            pendingNotifications.append((envelope, senderDeviceName))
            requestAuthorizationIfNeeded()
        case .denied:
            log("[MirroredNotificationPresenter] Notifications are denied in system settings; cannot mirror.")
        @unknown default:
            log("[MirroredNotificationPresenter] Unknown notification authorization status; skipping mirrored notification.")
        }
    }

    private func requestAuthorizationIfNeeded() {
        if authorizationRequestInFlight {
            return
        }

        authorizationRequestInFlight = true

        DispatchQueue.main.async {
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                self.queue.async {
                    self.authorizationRequestInFlight = false

                    if let error = error {
                        log("[MirroredNotificationPresenter] Authorization request failed: \(error.localizedDescription)")
                    }

                    guard granted else {
                        log("[MirroredNotificationPresenter] Authorization request not granted; dropping queued mirrored notifications.")
                        self.pendingNotifications.removeAll()
                        return
                    }

                    let queued = self.pendingNotifications
                    self.pendingNotifications.removeAll()
                    for (queuedEnvelope, queuedSender) in queued {
                        self.post(envelope: queuedEnvelope, senderDeviceName: queuedSender)
                    }
                }
            }
        }
    }

    private func post(envelope: MirroredNotificationEnvelope, senderDeviceName: String?) {
        let senderName = senderDeviceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSenderName = senderName?.isEmpty == false
        let displaySender = hasSenderName ? senderName! : "NotificationSyncFallbackSenderAndroid".localized()
        let identifierSender = hasSenderName ? senderName! : "android"
        let cleanAppName = envelope.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = envelope.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = envelope.body.trimmingCharacters(in: .whitespacesAndNewlines)

        let content = UNMutableNotificationContent()
        content.title = cleanTitle.isEmpty ? (cleanAppName.isEmpty ? "NotificationSyncFallbackTitle".localized() : cleanAppName) : cleanTitle
        content.body = cleanBody
        content.subtitle = cleanAppName.isEmpty ? displaySender : "\(cleanAppName) · \(displaySender)"
        content.sound = .default
        content.threadIdentifier = "quickdrop-mirror-\(sanitizeIdentifierComponent(identifierSender))"

        let identifier = makeIdentifier(sender: identifierSender, notificationKey: envelope.notificationKey)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        center.add(request) { error in
            if let error = error {
                log("[MirroredNotificationPresenter] Could not post notification: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    Settings.sharedInstance.incomingNotificationCount += 1
                    let count = Settings.sharedInstance.incomingNotificationCount
                    log("[MirroredNotificationPresenter] Posted mirrored notification (\(identifier)). Current count: \(count)")
                }
            }
        }
    }

    private func makeIdentifier(sender: String, notificationKey: String) -> String {
        let raw = "\(sender)|\(notificationKey)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let prefix = digest.prefix(12).map { String(format: "%02x", $0) }.joined()
        return "quickdrop-mirror-\(prefix)"
    }

    private func sanitizeIdentifierComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalarView = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let sanitized = String(scalarView)
        return sanitized.isEmpty ? "android" : sanitized
    }
}

private struct MirroredNotificationEnvelope: Codable {
    let version: Int
    let notificationKey: String
    let packageName: String
    let appName: String
    let title: String
    let body: String
    let postedAtEpochMs: Int64

    enum CodingKeys: String, CodingKey {
        case version
        case notificationKey
        case packageName
        case appName
        case title
        case body
        case postedAtEpochMs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        notificationKey = try container.decode(String.self, forKey: .notificationKey)
        packageName = try container.decode(String.self, forKey: .packageName)
        appName = try container.decode(String.self, forKey: .appName)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        postedAtEpochMs = try container.decode(Int64.self, forKey: .postedAtEpochMs)
    }
}
