// AppState.swift
// 全局应用状态

import SwiftUI
import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Onboarding
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - 用户基本信息
    @Published var userName: String = ""
    @Published var userHeight: Double = 0       // cm
    @Published var userBirthYear: Int = 0
    @Published var userGender: Gender = .notSet

    // MARK: - 单位设置
    @Published var weightUnit: WeightUnit = .kg

    // MARK: - 主题
    @Published var theme: AppTheme = .system

    // MARK: - 提醒
    @Published var reminderEnabled: Bool = false
    @Published var reminderHour: Int = 8
    @Published var reminderMinute: Int = 0

    // MARK: - Pro
    @Published var isPro: Bool = false

    // MARK: - 追踪指标配置
    @Published var enabledMetrics: [BodyMetricType] = [.weight, .bodyFat]

    // MARK: - 成就系统
    @Published var achievements: [Achievement] = []
    @Published var showAchievementNotification: Bool = false
    @Published var latestUnlockedAchievement: Achievement?

    private init() {
        load()
    }

    // MARK: - Enums

    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"
        case notSet = "notSet"

        var displayName: String {
            switch self {
            case .male: return L10n.string("男")
            case .female: return L10n.string("女")
            case .notSet: return L10n.string("不填")
            }
        }
    }

    enum WeightUnit: String, Codable, CaseIterable {
        case kg = "kg"
        case lb = "lb"

        func convert(_ value: Double, from source: WeightUnit) -> Double {
            if source == self { return value }
            switch self {
            case .kg: return value / 2.20462
            case .lb: return value * 2.20462
            }
        }
    }

    enum AppTheme: String, Codable {
        case system, light, dark
    }

    // MARK: - Codable Storage（独立结构体，避免 @MainActor 跨越隔离边界）

    private struct CodableData: Codable {
        var hasCompletedOnboarding: Bool
        var userName: String
        var userHeight: Double
        var userBirthYear: Int
        var userGender: Gender
        var weightUnit: WeightUnit
        var theme: AppTheme
        var reminderEnabled: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var isPro: Bool
        var enabledMetrics: [BodyMetricType]
        var achievements: [Achievement]
    }

    // MARK: - Persistence
    private static let storeURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app_state.json")
    }()

    func save() {
        // 立即保存，不使用延迟防抖，避免 App 被杀死时数据丢失
        performSave()
    }

    private func performSave() {
        let data = CodableData(
            hasCompletedOnboarding: hasCompletedOnboarding,
            userName: userName,
            userHeight: userHeight,
            userBirthYear: userBirthYear,
            userGender: userGender,
            weightUnit: weightUnit,
            theme: theme,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            isPro: isPro,
            enabledMetrics: enabledMetrics,
            achievements: achievements
        )
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: Self.storeURL)
        } catch {
            print("[AppState] Save error: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Self.storeURL)
            let decoded = try JSONDecoder().decode(CodableData.self, from: data)
            hasCompletedOnboarding = decoded.hasCompletedOnboarding
            userName = decoded.userName
            userHeight = decoded.userHeight
            userBirthYear = decoded.userBirthYear
            userGender = decoded.userGender
            weightUnit = decoded.weightUnit
            theme = decoded.theme
            reminderEnabled = decoded.reminderEnabled
            reminderHour = decoded.reminderHour
            reminderMinute = decoded.reminderMinute
            isPro = decoded.isPro
            enabledMetrics = decoded.enabledMetrics
            achievements = decoded.achievements
        } catch {
            // 首次启动，使用默认值
        }
    }

    // MARK: - Backup / Restore（用于 SettingsView 全量备份恢复）

    /// 将当前状态编码为 Data（用于备份）
    func encodeForBackup() -> Data {
        let data = CodableData(
            hasCompletedOnboarding: hasCompletedOnboarding,
            userName: userName,
            userHeight: userHeight,
            userBirthYear: userBirthYear,
            userGender: userGender,
            weightUnit: weightUnit,
            theme: theme,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            isPro: isPro,
            enabledMetrics: enabledMetrics,
            achievements: achievements
        )
        return (try? JSONEncoder().encode(data)) ?? Data()
    }

    /// 从备份数据恢复状态
    func restoreFromBackup(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(CodableData.self, from: data) else { return }
        hasCompletedOnboarding = decoded.hasCompletedOnboarding
        userName = decoded.userName
        userHeight = decoded.userHeight
        userBirthYear = decoded.userBirthYear
        userGender = decoded.userGender
        weightUnit = decoded.weightUnit
        theme = decoded.theme
        reminderEnabled = decoded.reminderEnabled
        reminderHour = decoded.reminderHour
        reminderMinute = decoded.reminderMinute
        isPro = decoded.isPro
        enabledMetrics = decoded.enabledMetrics
        achievements = decoded.achievements
    }

    // MARK: - Helpers

    /// 将 kg 值根据用户单位换算
    func displayWeight(_ kgValue: Double) -> (value: Double, unit: String) {
        switch weightUnit {
        case .kg: return (kgValue, "kg")
        case .lb: return (kgValue * 2.20462, "lb")
        }
    }

    /// 将用户输入的重量转换为 kg 存储
    func toKg(_ value: Double) -> Double {
        switch weightUnit {
        case .kg: return value
        case .lb: return value / 2.20462
        }
    }

    /// 计算 BMI（需要身高）
    func calculateBMI(weightKg: Double) -> Double? {
        guard userHeight > 0 else { return nil }
        let heightM = userHeight / 100.0
        return weightKg / (heightM * heightM)
    }

    // MARK: - Achievement Helpers

    /// 解锁新成就（由外部调用，如BodyEntryStore.save后）
    func unlockAchievements(_ newAchievements: [Achievement]) {
        guard !newAchievements.isEmpty else { return }
        // 去重：只添加未解锁的成就
        let existingIds = Set(achievements.map { $0.id })
        let filtered = newAchievements.filter { !existingIds.contains($0.id) }
        guard !filtered.isEmpty else { return }
        achievements.append(contentsOf: filtered)
        if let first = filtered.first {
            latestUnlockedAchievement = first
            showAchievementNotification = true
        }
        save()
    }

    /// 检查某成就是否已解锁
    func isAchievementUnlocked(_ type: AchievementType) -> Bool {
        achievements.contains { $0.id == type.id }
    }
}
