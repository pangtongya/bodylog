// NotificationManager.swift
// 本地通知管理（每日记录提醒）

import Foundation
import os.log
@preconcurrency import UserNotifications

// MARK: - File-scope constants (nonisolated, avoids @MainActor isolation warnings)

private let notificationLogger = Logger(subsystem: "com.pangtong.formlog", category: "NotificationManager")

/// Notification category identifiers
private let dailyReminderCategoryID = "DAILY_REMINDER_CATEGORY"
private let goalAchievedCategoryID = "GOAL_ACHIEVED_CATEGORY"

/// Notification action identifiers
private let recordNowActionID = "RECORD_NOW_ACTION"
private let snoozeActionID = "SNOOZE_ACTION"

@MainActor
final class NotificationManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()

    /// Notification request identifiers
    static let dailyReminderID = "formlog.daily_reminder"

    private override init() {
        super.init()
        notificationCenter.delegate = self
        registerNotificationCategories()
        notificationLogger.info("NotificationManager initialized")
    }

    // MARK: - Notification Categories & Actions

    /// Registers notification categories with interactive actions
    private func registerNotificationCategories() {
        // Daily reminder actions
        let recordNowAction = UNNotificationAction(
            identifier: recordNowActionID,
            title: L10n.string("现在记录"),
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionID,
            title: L10n.string("稍后提醒"),
            options: []
        )

        let dailyReminderCategory = UNNotificationCategory(
            identifier: dailyReminderCategoryID,
            actions: [recordNowAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Goal achieved category (no specific actions needed, just informative)
        let goalAchievedCategory = UNNotificationCategory(
            identifier: goalAchievedCategoryID,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            dailyReminderCategory,
            goalAchievedCategory
        ])
        notificationLogger.info("Notification categories registered")
    }

    // MARK: - 权限请求

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                notificationLogger.error("Request authorization failed: \(error.localizedDescription)")
            } else {
                notificationLogger.info("Authorization request completed, granted: \(granted)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func checkAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
            notificationLogger.debug("Authorization status checked: \(granted, privacy: .public)")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - 每日提醒

    /// Schedules a daily reminder notification at the specified time.
    /// - Parameters:
    ///   - hour: Hour of the reminder (0-23).
    ///   - minute: Minute of the reminder (0-59).
    /// - Returns: `true` if scheduling succeeded, `false` otherwise.
    @discardableResult
    func scheduleDailyReminder(hour: Int, minute: Int) -> Bool {
        // Validate inputs
        guard (0...23).contains(hour) else {
            notificationLogger.error("Invalid hour value: \(hour)")
            return false
        }
        guard (0...59).contains(minute) else {
            notificationLogger.error("Invalid minute value: \(minute)")
            return false
        }

        // Cancel any existing reminder first
        cancelDailyReminder()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = L10n.string("该记录了")
        content.body = L10n.string("记录今天的身体数据")
        content.sound = .default
        content.categoryIdentifier = dailyReminderCategoryID

        let request = UNNotificationRequest(
            identifier: Self.dailyReminderID,
            content: content,
            trigger: trigger
        )

        // add() is synchronous from the caller's perspective but has a callback for errors
        // We synchronously schedule; errors are logged via the callback below.
        notificationCenter.add(request) { error in
            if let error = error {
                notificationLogger.error("Failed to schedule daily reminder: \(error.localizedDescription)")
            } else {
                notificationLogger.info("Daily reminder scheduled at \(hour):\(String(format: "%02d", minute))")
            }
        }

        // Return true optimistically; real errors are logged asynchronously
        return true
    }

    /// Cancels the daily reminder notification.
    /// - Returns: `true` if the cancellation was performed (no error reporting from the API).
    @discardableResult
    func cancelDailyReminder() -> Bool {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderID])
        notificationLogger.info("Daily reminder cancelled")
        return true
    }

    // MARK: - 目标达成通知

    /// Sends a one-time notification celebrating a goal achievement.
    /// - Parameter metricName: The name of the metric that reached its goal.
    /// - Returns: `true` if the notification was scheduled successfully, `false` otherwise.
    @discardableResult
    func sendGoalAchievedNotification(metricName: String) -> Bool {
        guard !metricName.isEmpty else {
            notificationLogger.warning("sendGoalAchievedNotification called with empty metricName")
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = L10n.string("目标达成！🎉")
        content.body = L10n.string("恭喜你，%@ 已达到目标值！", metricName)
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = goalAchievedCategoryID

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "formlog.goal_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                notificationLogger.error("Failed to send goal achievement notification: \(error.localizedDescription)")
            } else {
                notificationLogger.info("Goal achievement notification sent for metric: \(metricName)")
            }
        }

        return true
    }

    // MARK: - Sync with AppState

    /// Reads reminder settings from `AppState` and updates scheduled notifications accordingly.
    /// If reminders are enabled, (re)schedules the daily reminder at the configured time.
    /// If reminders are disabled, cancels any pending daily reminder.
    /// Call this at app launch or whenever AppState reminder settings change externally.
    func syncWithAppState() {
        let appState = AppState.shared

        notificationLogger.debug("Syncing notifications with AppState — enabled: \(appState.reminderEnabled), hour: \(appState.reminderHour), minute: \(appState.reminderMinute)")

        if appState.reminderEnabled {
            // Check authorization before scheduling
            notificationCenter.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    notificationLogger.warning("Cannot sync daily reminder: authorization status is \(String(describing: settings.authorizationStatus.rawValue))")
                    return
                }
                DispatchQueue.main.async {
                    _ = self.scheduleDailyReminder(
                        hour: appState.reminderHour,
                        minute: appState.reminderMinute
                    )
                }
            }
        } else {
            cancelDailyReminder()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let categoryID = notification.request.content.categoryIdentifier
        notificationLogger.info("Notification will present in foreground, category: \(categoryID)")

        var options: UNNotificationPresentationOptions = [.banner, .sound]

        // On iOS 15+ we can also show the list and badge
        if #available(iOS 15.0, *) {
            options.insert(.list)
        }

        completionHandler(options)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let notificationID = response.notification.request.identifier
        let categoryID = response.notification.request.content.categoryIdentifier

        notificationLogger.info("Notification response received — action: \(actionID), notificationID: \(notificationID), category: \(categoryID)")

        switch actionID {
        case recordNowActionID:
            notificationLogger.info("User tapped 'Record Now' from notification")
            // Post a notification so the app can navigate to the recording screen
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .init("com.pangtong.formlog.openRecording"), object: nil)
            }

        case snoozeActionID:
            notificationLogger.info("User tapped 'Snooze' — scheduling a 30-minute follow-up")
            // Schedule a one-time reminder 30 minutes from now
            let snoozeContent = UNMutableNotificationContent()
            snoozeContent.title = L10n.string("该记录了")
            snoozeContent.body = L10n.string("别忘了记录今天的身体数据哦 😊")
            snoozeContent.sound = .default
            snoozeContent.categoryIdentifier = dailyReminderCategoryID

            let snoozeTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
            let snoozeRequest = UNNotificationRequest(
                identifier: "formlog.daily_reminder_snooze",
                content: snoozeContent,
                trigger: snoozeTrigger
            )
            center.add(snoozeRequest) { error in
                if let error = error {
                    notificationLogger.error("Failed to schedule snooze notification: \(error.localizedDescription)")
                }
            }

        case UNNotificationDefaultActionIdentifier:
            notificationLogger.info("User tapped the notification itself (default action)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .init("com.pangtong.formlog.openRecording"), object: nil)
            }

        default:
            notificationLogger.debug("Unhandled notification action: \(actionID)")
        }

        completionHandler()
    }
}
