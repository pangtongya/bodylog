// AppState.swift
// 全局应用状态管理
// 负责存储和同步应用的所有用户配置、偏好设置和状态
// 采用单例模式，使用 @MainActor 确保线程安全

import SwiftUI
import Foundation
import os.log

/// 全局应用状态单例
/// 使用 @MainActor 确保所有属性访问都在主线程，符合 SwiftUI 的要求
/// 提供持久化存储、数据验证和备份恢复功能
@MainActor
class AppState: ObservableObject {

    /// 单例实例
    static let shared = AppState()

    // MARK: - Logger

    private static let logger = Logger(subsystem: "com.pangtong.formlog", category: "AppState")

    // MARK: - Safety Constants

    /// Maximum allowed backup data size (1 MB). Backups exceeding this are rejected to prevent restoring corrupted/huge data.
    private static let maxBackupDataSize: Int = 1_048_576 // 1 MB

    // MARK: - Onboarding

    /// 用户是否已完成首次引导
    /// 初次打开应用时显示引导流程，完成后设置为 true
    @Published var hasCompletedOnboarding: Bool = false

    // MARK: - 用户基本信息

    /// 用户显示名称
    @Published var userName: String = ""

    /// 用户身高（厘米）
    @Published var userHeight: Double = 0

    /// 用户性别
    @Published var userGender: Gender = .notSet

    // MARK: - 单位设置

    /// 重量单位设置（kg 或 lb）
    @Published var weightUnit: WeightUnit = .kg

    // MARK: - 主题

    /// 应用主题设置
    @Published var theme: AppTheme = .system

    // MARK: - 提醒

    /// 是否启用提醒功能
    @Published var reminderEnabled: Bool = false

    /// 提醒时间的小时（0-23）
    @Published var reminderHour: Int = 8

    /// 提醒时间的分钟（0-59）
    @Published var reminderMinute: Int = 0

    // MARK: - Pro

    /// 用户是否是 Pro 会员
    @Published var isPro: Bool = false

    // MARK: - 追踪指标配置

    /// 启用的身体指标类型列表
    /// 系统会根据此列表决定在记录页面显示哪些指标
    /// 有效的指标类型来自 BodyMetricType 枚举
    @Published var enabledMetrics: [BodyMetricType] = [.weight, .bodyFat]

    /// 禁用的指标类型列表
    /// 用于快速访问未启用的指标类型
    /// 此列表会根据 enabledMetrics 自动更新
    @Published var disabledMetrics: [BodyMetricType] = []

    // MARK: - 成就系统

    /// 用户已解锁的成就列表
    @Published var achievements: [Achievement] = []

    /// 是否显示成就通知
    /// 用于控制新成就解锁时的通知显示
    @Published var showAchievementNotification: Bool = false

    /// 最近解锁的成就
    /// 用于动画效果和通知内容
    @Published var latestUnlockedAchievement: Achievement?

    // MARK: - Initialization

    /// 私有初始化方法，确保单例模式
    /// 自动加载持久化数据
    private init() {
        load()
    }

    // MARK: - Enums

    /// 用户性别枚举
    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"
        case notSet = "notSet"

        /// 性别的本地化显示名称
        var displayName: String {
            switch self {
            case .male: return L10n.string("男")
            case .female: return L10n.string("女")
            case .notSet: return L10n.string("不填")
            }
        }
    }

    /// 重量单位枚举
    internal enum WeightUnit: String, Codable, CaseIterable {
        case kg = "kg"
        case lb = "lb"

        /// 在两种单位之间进行转换
        /// - Parameters:
        ///   - value: 要转换的重量值
        ///   - source: 原始单位
        /// - Returns: 转换后的重量值（kg）
        func convert(_ value: Double, from source: WeightUnit) -> Double {
            if source == self { return value }
            switch self {
            case .kg: return value / 2.20462
            case .lb: return value * 2.20462
            }
        }
    }

    /// 应用主题枚举
    enum AppTheme: String, Codable {
        case system, light, dark
    }

    /// 当前数据架构版本，用于支持数据迁移
    /// 当需要修改数据结构时，增加此版本号并实现迁移逻辑
    private static let currentSchemaVersion = 1

    // MARK: - Codable Storage（独立结构体，避免 @MainActor 跨越隔离边界）

    /// 用于序列化存储的 Codable 结构体
    /// 使用独立结构体避免 @MainActor 类跨越隔离边界
    private struct CodableData: Codable {
        var schemaVersion: Int
        var hasCompletedOnboarding: Bool
        var userName: String
        var userHeight: Double
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

    /// 应用状态文件的存储 URL
    /// 优先使用文档目录，文档目录不可用时回退到临时目录
    private static let storeURL: URL = {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fallbackDir = FileManager.default.temporaryDirectory
        let baseURL = docsDir ?? fallbackDir
        return baseURL.appendingPathComponent("app_state.json")
    }()

    /// 保存当前状态到持久化存储
    /// 立即保存，不使用延迟防抖，避免 App 被杀死时数据丢失
    func save() {
        preSaveValidation()
        performSave()
    }

    /// 执行实际的保存操作
    private func performSave() {
        let data = CodableData(
            schemaVersion: Self.currentSchemaVersion,
            hasCompletedOnboarding: hasCompletedOnboarding,
            userName: userName,
            userHeight: userHeight,
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
            try encoded.write(to: Self.storeURL, options: [.atomic, .completeFileProtection])
        } catch {
            Self.logger.error("Save error: \(error.localizedDescription)")
        }
    }

    /// 从持久化存储加载状态
    /// 如果加载失败或文件不存在，使用默认值
    private func load() {
        do {
            let data = try Data(contentsOf: Self.storeURL)
            let decoded = try JSONDecoder().decode(CodableData.self, from: data)
            // Handle schema migration
            if decoded.schemaVersion < Self.currentSchemaVersion {
                migrateFromSchema(decoded.schemaVersion, to: Self.currentSchemaVersion, decoded: decoded)
            } else {
                applyDecodedData(decoded)
            }
        } catch {
            // 首次启动，使用默认值
            Self.logger.warning("Load failed (\(error.localizedDescription)). Starting with default values.")
        }
    }

    /// 应用解码的数据，并进行必要的验证和修复
    private func applyDecodedData(_ decoded: CodableData) {
        hasCompletedOnboarding = decoded.hasCompletedOnboarding
        userName = decoded.userName
        userHeight = decoded.userHeight

        // 验证枚举值有效性，防止数据损坏
        userGender = validateGender(decoded.userGender) ?? .notSet
        weightUnit = validateWeightUnit(decoded.weightUnit) ?? .kg
        theme = validateTheme(decoded.theme) ?? .system

        reminderEnabled = decoded.reminderEnabled
        reminderHour = max(0, min(23, decoded.reminderHour))  // 确保小时在 0-23 范围内
        reminderMinute = max(0, min(59, decoded.reminderMinute))  // 确保分钟在 0-59 范围内
        isPro = decoded.isPro

        // 验证并清理启用的指标，移除任何无效的指标类型
        enabledMetrics = decoded.enabledMetrics.compactMap { validateMetricType($0) }

        // 确保至少保留两个默认指标
        if enabledMetrics.isEmpty {
            enabledMetrics = [.weight, .bodyFat]
        }

        achievements = decoded.achievements
    }

    // MARK: - Validation Methods（数据完整性验证）

    /// 验证性别枚举值的有效性
    /// - Parameter gender: 要验证的性别值
    /// - Returns: 如果有效则返回原始值，否则返回 nil
    private func validateGender(_ gender: Gender) -> Gender? {
        return Gender.allCases.contains(gender) ? gender : nil
    }

    /// 验证重量单位枚举值的有效性
    /// - Parameter unit: 要验证的单位值
    /// - Returns: 如果有效则返回原始值，否则返回 nil
    private func validateWeightUnit(_ unit: WeightUnit) -> WeightUnit? {
        return WeightUnit.allCases.contains(unit) ? unit : nil
    }

    /// 验证主题枚举值的有效性
    /// - Parameter theme: 要验证的主题值
    /// - Returns: 如果有效则返回原始值，否则返回 nil
    private func validateTheme(_ theme: AppTheme) -> AppTheme? {
        return [.system, .light, .dark].contains(theme) ? theme : nil
    }

    /// 验证指标类型枚举值的有效性
    /// - Parameter type: 要验证的指标类型
    /// - Returns: 如果有效则返回原始值，否则返回 nil
    private func validateMetricType(_ type: BodyMetricType) -> BodyMetricType? {
        return BodyMetricType.allCases.contains(type) ? type : nil
    }

    /// 验证所有指标配置的有效性
    /// - Returns: true 如果所有指标配置都是有效的
    /// - Note: 此方法会自动清理无效的指标类型
    func validateAllMetrics() -> Bool {
        let previousCount = enabledMetrics.count
        // 清理无效的指标
        enabledMetrics = enabledMetrics.compactMap { validateMetricType($0) }
        let cleanedCount = enabledMetrics.count

        // 更新禁用指标列表
        disabledMetrics = BodyMetricType.allCases.filter { !enabledMetrics.contains($0) }

        // 确保至少保留两个默认指标
        if enabledMetrics.isEmpty {
            enabledMetrics = [.weight, .bodyFat]
        }

        // 如果数据被清理过，保存到持久化存储
        if previousCount != cleanedCount {
            save()
        }

        return previousCount == cleanedCount
    }

    private func migrateFromSchema(_ fromVersion: Int, to toVersion: Int, decoded: CodableData) {
        // Apply migrations incrementally
        let current = decoded
        // Future: add migration steps here when schema version increases
        // e.g., if fromVersion < 2 { migrateToV2(&current) }
        applyDecodedData(current)
    }

    // MARK: - Pre-save Validation

    /// Runs before every save() call to catch last-minute inconsistencies.
    /// Corrects invalid state in-place so the persisted snapshot is always sane.
    private func preSaveValidation() {
        // Clamp reminder hour / minute
        reminderHour = max(0, min(23, reminderHour))
        reminderMinute = max(0, min(59, reminderMinute))

        // Ensure height is non-negative
        userHeight = max(0, userHeight)

        // Strip unknown metric types and guarantee at least the defaults
        enabledMetrics = enabledMetrics.compactMap { validateMetricType($0) }
        if enabledMetrics.isEmpty {
            enabledMetrics = [.weight, .bodyFat]
        }

        // Rebuild disabled metrics list to stay in sync
        disabledMetrics = BodyMetricType.allCases.filter { !enabledMetrics.contains($0) }
    }

    // MARK: - Safe BodyMetricType Decoding

    /// Wrapper that decodes `[BodyMetricType]` safely by first reading `[String]`
    /// and then mapping each raw value to a `BodyMetricType`. Invalid names are
    /// silently dropped instead of crashing the JSONDecoder.
    private struct SafeMetricList: Codable {
        var metrics: [BodyMetricType]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawStrings = try container.decode([String].self)
            metrics = rawStrings.compactMap { BodyMetricType(rawValue: $0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(metrics.map { $0.rawValue })
        }
    }

    // MARK: - Backup / Restore（用于 SettingsView 全量备份恢复）

    /// 将当前状态编码为 Data（用于备份）
    /// - Returns: 编码后的数据，如果编码失败则返回空的 Data
    func encodeForBackup() -> Data {
        let data = CodableData(
            schemaVersion: Self.currentSchemaVersion,
            hasCompletedOnboarding: hasCompletedOnboarding,
            userName: userName,
            userHeight: userHeight,
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
    /// - Parameter data: 包含应用状态的备份数据
    /// - Returns: true 如果恢复成功，false 如果备份数据无效
    /// - Note: 此方法会自动验证数据完整性并清理无效值
    func restoreFromBackup(_ data: Data) -> Bool {
        // Guard against unreasonably large backups (e.g., corrupted / malicious data)
        guard data.count <= Self.maxBackupDataSize else {
            Self.logger.error("Backup rejected: data size \(data.count) exceeds maximum allowed \(Self.maxBackupDataSize) bytes")
            return false
        }

        // --- Strategy: Decode metrics separately via SafeMetricList so that
        //     unknown/invalid metric names in the JSON do not crash the decoder.
        //     We attempt a full CodableData decode first (fast path); if that
        //     fails we fall back to a manual JSON parse with safe metric decoding.
        if let decoded = try? JSONDecoder().decode(CodableData.self, from: data) {
            applyBackupDecoded(decoded)
            return true
        }

        // Slow path — attempt safe decoding with metric name fallback
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.logger.warning("Backup decode failed: data is not valid JSON")
            return false
        }

        // Schema version
        let schemaVersion = json["schemaVersion"] as? Int ?? 0

        // --- Decode enabledMetrics safely as [String] → [BodyMetricType] ---
        var enabledMetrics: [BodyMetricType] = [.weight, .bodyFat]
        if let rawMetrics = json["enabledMetrics"] as? [String] {
            let safe = rawMetrics.compactMap { BodyMetricType(rawValue: $0) }
            if !safe.isEmpty { enabledMetrics = safe }
        }

        // --- Decode simple keyed values with UserDefaults-style do-catch safety ---
        func safeDecode<T: Decodable>(_ key: String, as type: T.Type, fallback: T) -> T {
            guard let value = json[key] else { return fallback }
            do {
                let rawData = try JSONSerialization.data(withJSONObject: value)
                return try JSONDecoder().decode(T.self, from: rawData)
            } catch {
                Self.logger.warning("Backup field '\(key)' decode failed: \(error.localizedDescription). Using fallback.")
                return fallback
            }
        }

        let hasCompletedOnboarding = safeDecode("hasCompletedOnboarding", as: Bool.self, fallback: false)
        let userName              = safeDecode("userName",              as: String.self, fallback: "")
        let userHeight            = safeDecode("userHeight",            as: Double.self, fallback: 0.0)
        let userGender            = safeDecode("userGender",            as: Gender.self,  fallback: .notSet)
        let weightUnit            = safeDecode("weightUnit",            as: WeightUnit.self, fallback: .kg)
        let theme                 = safeDecode("theme",                 as: AppTheme.self, fallback: .system)
        let reminderEnabled       = safeDecode("reminderEnabled",       as: Bool.self,    fallback: false)
        let reminderHour          = safeDecode("reminderHour",          as: Int.self,     fallback: 8)
        let reminderMinute        = safeDecode("reminderMinute",        as: Int.self,     fallback: 0)
        let isPro                 = safeDecode("isPro",                 as: Bool.self,    fallback: false)

        // --- Decode achievements (array of Codable objects) ---
        var achievements: [Achievement] = []
        if let achArray = json["achievements"] as? [[String: Any]] {
            do {
                let achData = try JSONSerialization.data(withJSONObject: achArray)
                achievements = (try? JSONDecoder().decode([Achievement].self, from: achData)) ?? []
            } catch {
                Self.logger.warning("Backup achievements decode failed: \(error.localizedDescription)")
            }
        }

        // Apply everything through the validated path
        let reconstructed = CodableData(
            schemaVersion: schemaVersion,
            hasCompletedOnboarding: hasCompletedOnboarding,
            userName: userName,
            userHeight: userHeight,
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

        applyBackupDecoded(reconstructed)
        return true
    }

    /// Shared helper: applies a decoded CodableData (from load or backup) with
    /// schema migration and persistence.
    private func applyBackupDecoded(_ decoded: CodableData) {
        if decoded.schemaVersion < Self.currentSchemaVersion {
            migrateFromSchema(decoded.schemaVersion, to: Self.currentSchemaVersion, decoded: decoded)
        } else {
            applyDecodedData(decoded)
        }
        save()
    }

    // MARK: - UserDefaults Safety Helpers

    /// Safely read a value from UserDefaults with error logging for corrupted data.
    /// - Parameters:
    ///   - key: The UserDefaults key.
    ///   - defaultValue: Fallback value if the key is missing or data is corrupted.
    /// - Returns: The decoded value or the default.
    private static func safeUserDefaultsRead<T>(_ key: String, defaultValue: T) -> T where T: Codable {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return defaultValue
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.warning("UserDefaults key '\(key)' corrupted: \(error.localizedDescription). Returning default.")
            return defaultValue
        }
    }

    /// Safely write a value to UserDefaults.
    /// - Parameters:
    ///   - value: The value to encode and store.
    ///   - key: The UserDefaults key.
    private static func safeUserDefaultsWrite<T>(_ value: T, forKey key: String) where T: Codable {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            logger.warning("UserDefaults write for key '\(key)' failed: \(error.localizedDescription)")
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
