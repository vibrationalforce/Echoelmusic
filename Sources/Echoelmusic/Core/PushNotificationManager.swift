// PushNotificationManager.swift
// Echoelmusic - APNs Push Notification Infrastructure
//
// Handles device registration, notification categories, and incoming
// push notifications for app updates, wellness reminders, and session events.
//
// Created 2026-02-17
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import CloudKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Notification Categories

/// All notification categories supported by Echoelmusic
public enum EchoelNotificationCategory: String, CaseIterable {
    case appUpdate = "ECHOEL_APP_UPDATE"
    case featureAnnouncement = "ECHOEL_FEATURE"
    case wellnessReminder = "ECHOEL_WELLNESS"
    case sessionReminder = "ECHOEL_SESSION"
    case bioAlert = "ECHOEL_BIO_ALERT"
    case communityEvent = "ECHOEL_COMMUNITY"
}

/// Actionable notification actions
public enum EchoelNotificationAction: String {
    case openUpdate = "OPEN_UPDATE"
    case dismiss = "DISMISS"
    case startSession = "START_SESSION"
    case viewDetails = "VIEW_DETAILS"
    case startWellness = "START_WELLNESS"
}

// MARK: - Push Notification Manager

/// Manages APNs registration, permission requests, and notification handling
@MainActor
public final class PushNotificationManager: NSObject, ObservableObject {

    public static let shared = PushNotificationManager()

    // MARK: - Published State

    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var deviceToken: String?
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public private(set) var lastNotification: [AnyHashable: Any]?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
        checkCurrentStatus()
    }

    // MARK: - Authorization

    /// Request push notification permission from the user
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound, .provisional])

            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                registerForRemoteNotifications()
            }

            await refreshStatus()
            return granted
        } catch {
            log.error("Push authorization failed: \(error.localizedDescription)", category: .system)
            return false
        }
    }

    /// Register with APNs for remote notifications
    public func registerForRemoteNotifications() {
        #if canImport(UIKit) && !os(watchOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Check current authorization status
    public func checkCurrentStatus() {
        Task {
            await refreshStatus()
        }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
        }
    }

    // MARK: - Device Token

    /// Called from AppDelegate when APNs registration succeeds
    public func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        log.info("APNs device token registered: \(token.prefix(8))...", category: .system)

        // Store token securely in Keychain (not UserDefaults which is unencrypted)
        _ = EnhancedKeychainManager.shared.store(key: "echoelmusic_apns_token", value: token)

        // Store token in CloudKit for server-side push delivery
        saveTokenToCloudKit(token)

        // Publish via bus so other engines can react
        EngineBus.shared.publish(.custom(
            topic: "push.registered",
            payload: ["tokenPrefix": String(token.prefix(16))]
        ))
    }

    /// Called from AppDelegate when APNs registration fails
    public func didFailToRegisterForRemoteNotifications(error: Error) {
        log.error("APNs registration failed: \(error.localizedDescription)", category: .system)
        self.deviceToken = nil
    }

    // MARK: - Notification Categories

    /// Register all actionable notification categories
    private func registerCategories() {
        let updateCategory = UNNotificationCategory(
            identifier: EchoelNotificationCategory.appUpdate.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: EchoelNotificationAction.openUpdate.rawValue,
                    title: "View Update",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: EchoelNotificationAction.dismiss.rawValue,
                    title: "Later",
                    options: [.destructive]
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let featureCategory = UNNotificationCategory(
            identifier: EchoelNotificationCategory.featureAnnouncement.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: EchoelNotificationAction.viewDetails.rawValue,
                    title: "View Details",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let wellnessCategory = UNNotificationCategory(
            identifier: EchoelNotificationCategory.wellnessReminder.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: EchoelNotificationAction.startWellness.rawValue,
                    title: "Start Session",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: EchoelNotificationAction.dismiss.rawValue,
                    title: "Skip",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let sessionCategory = UNNotificationCategory(
            identifier: EchoelNotificationCategory.sessionReminder.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: EchoelNotificationAction.startSession.rawValue,
                    title: "Open Session",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let bioCategory = UNNotificationCategory(
            identifier: EchoelNotificationCategory.bioAlert.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: EchoelNotificationAction.viewDetails.rawValue,
                    title: "View",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let communityCategory = UNNotificationCategory(
            identifier: EchoelNotificationCategory.communityEvent.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: EchoelNotificationAction.viewDetails.rawValue,
                    title: "Join",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            updateCategory,
            featureCategory,
            wellnessCategory,
            sessionCategory,
            bioCategory,
            communityCategory
        ])
    }

    // MARK: - Local Notifications (Wellness Reminders)

    /// Schedule a circadian-aware wellness reminder
    public func scheduleWellnessReminder(hour: Int, minute: Int, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Echoelmusic Wellness"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = EchoelNotificationCategory.wellnessReminder.rawValue

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "wellness_\(hour)_\(minute)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                log.error("Failed to schedule wellness reminder: \(error.localizedDescription)", category: .system)
            }
        }
    }

    /// Schedule a session reminder for a specific date
    public func scheduleSessionReminder(date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = EchoelNotificationCategory.sessionReminder.rawValue

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                log.error("Failed to schedule session reminder: \(error.localizedDescription)", category: .system)
            }
        }
    }

    /// Remove all pending wellness reminders
    public func cancelWellnessReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let wellnessIDs = requests
                .filter { $0.identifier.hasPrefix("wellness_") }
                .map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: wellnessIDs)
        }
    }

    // MARK: - CloudKit Device Token Storage

    private static let cloudKitContainer = CKContainer(identifier: "iCloud.com.echoelmusic.app")
    private static let tokenRecordType = "DeviceToken"

    /// Save device token to CloudKit public database for server-side push delivery
    private func saveTokenToCloudKit(_ token: String) {
        let container = Self.cloudKitContainer
        let publicDB = container.publicCloudDatabase

        // Use a deterministic record ID so the same device updates its token
        #if canImport(UIKit) && !os(watchOS)
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let deviceID = UserDefaults.standard.string(forKey: "echoelmusic_device_id")
            ?? { let id = UUID().uuidString; UserDefaults.standard.set(id, forKey: "echoelmusic_device_id"); return id }()
        #endif

        let recordID = CKRecord.ID(recordName: "token_\(deviceID)")
        let record = CKRecord(recordType: Self.tokenRecordType, recordID: recordID)
        record["token"] = token as CKRecordValue
        record["platform"] = Self.currentPlatform as CKRecordValue
        record["appVersion"] = Self.appVersion as CKRecordValue
        record["locale"] = Locale.current.identifier as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue

        let operation = CKModifyRecordsOperation(recordsToSave: [record])
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                log.info("Device token saved to CloudKit", category: .system)
            case .failure(let error):
                log.error("CloudKit token save failed: \(error.localizedDescription)", category: .system)
            }
        }
        publicDB.add(operation)
    }

    private static var currentPlatform: String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #elseif os(watchOS)
        return "watchos"
        #elseif os(tvOS)
        return "tvos"
        #elseif os(visionOS)
        return "visionos"
        #else
        return "unknown"
        #endif
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground — show as banner
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap / action
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier

        Task { @MainActor in
            self.lastNotification = userInfo

            // Publish to bus so any engine can react
            EngineBus.shared.publish(.custom(
                topic: "push.tapped",
                payload: [
                    "category": category,
                    "action": actionID
                ]
            ))

            log.info("Push notification tapped: category=\(category) action=\(actionID)", category: .system)
        }

        completionHandler()
    }
}
