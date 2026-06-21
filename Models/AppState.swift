// AppState.swift
// 全局应用状态

import SwiftUI
import Foundation

@MainActor
class AppState: ObservableObject, Codable {
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

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, userName, userHeight, userBirthYear, userGender
        case weightUnit, theme, reminderEnabled, reminderHour, reminderMinute
        case isPro, enabledMetrics, achievements
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(userName, forKey: .userName)
        try c.encode(userHeight, forKey: .userHeight)
        try c.encode(userBirthYear, forKey: .userBirthYear)
        try c.encode(userGender, forKey: .userGender)
        try c.encode(weightUnit, forKey: .weightUnit)
        try c.encode(theme, forKey: .theme)
        try c.encode(reminderEnabled, forKey: .reminderEnabled)
        try c.encode(reminderHour, forKey: .reminderHour)
        try c.encode(reminderMinute, forKey: .reminderMinute)
        try c.encode(isPro, forKey: .isPro)
        try c.encode(enabledMetrics, forKey: .enabledMetrics)
        try c.encode(achievements, forKey: .achievements)
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = (try? c.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        userName = (try? c.decode(String.self, forKey: .userName)) ?? ""
        userHeight = (try? c.decode(Double.self, forKey: .userHeight)) ?? 0
        userBirthYear = (try? c.decode(Int.self, forKey: .userBirthYear)) ?? 0
        userGender = (try? c.decode(Gender.self, forKey: .userGender)) ?? .notSet
        weightUnit = (try? c.decode(WeightUnit.self, forKey: .weightUnit)) ?? .kg
        theme = (try? c.decode(AppTheme.self, forKey: .theme)) ?? .system
        reminderEnabled = (try? c.decode(Bool.self, forKey: .reminderEnabled)) ?? false
        reminderHour = (try? c.decode(Int.self, forKey: .reminderHour)) ?? 8
        reminderMinute = (try? c.decode(Int.self, forKey: .reminderMinute)) ?? 0
        isPro = (try? c.decode(Bool.self, forKey: .isPro)) ?? false
        enabledMetrics = (try? c.decode([BodyMetricType].self, forKey: .enabledMetrics)) ?? [.weight, .bodyFat]
        achievements = (try? c.decode([Achievement].self, forKey: .achievements)) ?? []
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
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: Self.storeURL)
        } catch {
            print("[AppState] Save error: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Self.storeURL)
            let decoded = try JSONDecoder().decode(AppState.self, from: data)
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
