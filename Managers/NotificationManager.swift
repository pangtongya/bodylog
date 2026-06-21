// NotificationManager.swift
// 本地通知管理（每日记录提醒）

import Foundation
@preconcurrency import UserNotifications

final class NotificationManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = NotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - 权限请求

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func checkAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            let granted = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - 每日提醒

    func scheduleDailyReminder(hour: Int, minute: Int) {
        // 先取消旧的
        cancelDailyReminder()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = L10n.string("记录今天的数据 💪")
        content.body = L10n.string("打开 FormLog，记录今天的身体指标，见证每一点变化。")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "formlog.daily_reminder",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("[NotificationManager] Schedule error: \(error)")
            }
        }
    }

    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["formlog.daily_reminder"])
    }

    // MARK: - 目标达成通知

    func sendGoalAchievedNotification(metricName: String) {
        let content = UNMutableNotificationContent()
        content.title = L10n.string("目标达成！🎉")
        content.body = String(format: L10n.string("恭喜你，%@ 已达到目标值！"), metricName)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "formlog.goal_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request) { _ in }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 前台也显示通知
        completionHandler([.banner, .sound])
    }
}
