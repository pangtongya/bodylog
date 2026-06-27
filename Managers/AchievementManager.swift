// AchievementManager.swift
// 成就系统管理器 - 检查和解锁成就

import Foundation
import os

/// 成就管理器 - 单例模式
@MainActor
final class AchievementManager {

    static let shared = AchievementManager()

    private let logger = Logger(subsystem: "com.bodylog.achievements", category: "AchievementManager")

    private init() {}

    // MARK: - Cache

    /// Cache key: stores timestamp of last achievement check
    private var lastCheckTimestamp: Date = .distantPast

    /// Throttle interval for `checkAndUnlockAchievements`
    private static let checkThrottleInterval: TimeInterval = 30

    /// Cache for progress results — keyed by achievement type ID
    private var progressCache: [String: (current: Int, target: Int)] = [:]

    /// Timestamp of last progress cache population
    private var progressCacheTimestamp: Date = .distantPast

    /// How long progress cache stays valid
    private static let progressCacheTTL: TimeInterval = 60

    // MARK: - Public API

    /// 检查并解锁新成就（在每次保存数据后调用）
    /// - Returns: 新解锁的成就列表（用于显示通知）
    @discardableResult
    func checkAndUnlockAchievements(
        entryStore: BodyEntryStore,
        goalStore: GoalStore,
        existingAchievements: [Achievement]
    ) -> [Achievement] {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastCheckTimestamp)
        if elapsed < Self.checkThrottleInterval {
            let elapsedStr = String(format: "%.2f", elapsed)
            logger.debug("Skipping achievement check — last check was \(elapsedStr)s ago (throttle: \(Self.checkThrottleInterval)s)")
            return []
        }
        lastCheckTimestamp = now

        var newAchievements: [Achievement] = []
        let unlockedIds = Set(existingAchievements.map { $0.id })

        // 检查每个成就类型
        for type in AchievementType.allCases {
            // 跳过已解锁的成就
            if unlockedIds.contains(type.id) { continue }

            // 检查是否满足条件
            if isUnlocked(type: type, entryStore: entryStore, goalStore: goalStore) {
                let achievement = Achievement(type: type)
                newAchievements.append(achievement)
                logger.info("Achievement unlocked: \(type.id)")
            }
        }

        // 限制返回数量（防止通知过载）
        if newAchievements.count > 3 {
            logger.info("Throttling notification — \(newAchievements.count) achievements unlocked, returning first 3")
            return Array(newAchievements.prefix(3))
        }

        if !newAchievements.isEmpty {
            logger.info("Returning \(newAchievements.count) new achievement(s)")
        }

        return newAchievements
    }

    /// 检查单个成就是否应该被解锁
    func isUnlocked(
        type: AchievementType,
        entryStore: BodyEntryStore,
        goalStore: GoalStore
    ) -> Bool {
        switch type {
        // 连续记录成就
        case .streak3:
            return entryStore.currentStreak >= 3
        case .streak7:
            return entryStore.currentStreak >= 7
        case .streak14:
            return entryStore.currentStreak >= 14
        case .streak30:
            return entryStore.currentStreak >= 30
        case .streak60:
            return entryStore.currentStreak >= 60
        case .streak100:
            return entryStore.currentStreak >= 100

        // 数据量成就
        case .records10:
            return entryStore.entries.count >= 10
        case .records50:
            return entryStore.entries.count >= 50
        case .records100:
            return entryStore.entries.count >= 100
        case .records365:
            return entryStore.entries.count >= 365

        // 照片成就
        case .photoFirst:
            return entryStore.photoCount > 0
        case .photos10:
            return entryStore.photoCount >= 10
        case .photos30:
            return entryStore.photoCount >= 30
        case .photoCompare:
            return entryStore.hasUsedPhotoCompare

        // 目标成就
        case .goalFirst:
            return goalStore.goals.count > 0
        case .goalComplete:
            return goalStore.goals.contains { $0.isAchieved }
        case .goals5:
            let completedCount = goalStore.goals.filter { $0.isAchieved }.count
            return completedCount >= 5
        case .weightLoss5:
            return hasAchievedWeightLoss(entryStore: entryStore, percentage: 5)
        case .bodyFatLoss5:
            return hasAchievedBodyFatLoss(entryStore: entryStore, percentage: 5)

        // 里程碑成就
        case .weekPerfect:
            return hasPerfectWeek(entryStore: entryStore)
        case .monthPerfect:
            return hasPerfectMonth(entryStore: entryStore)
        case .shareFirst:
            return UserDefaults.standard.bool(forKey: "hasSharedFirst")
        case .exportData:
            return UserDefaults.standard.bool(forKey: "hasExportedData")
        case .reminderSet:
            return UserDefaults.standard.bool(forKey: "hasSetReminder")
        }
    }

    // MARK: - Progress Tracking

    /// 获取某个成就类型的当前进度（用于进度条显示）
    /// Results are cached for 60 seconds to avoid redundant recalculations.
    func progress(for type: AchievementType, entryStore: BodyEntryStore, goalStore: GoalStore) -> (current: Int, target: Int)? {
        let now = Date()
        let elapsed = now.timeIntervalSince(progressCacheTimestamp)

        if elapsed < Self.progressCacheTTL, let cached = progressCache[type.id] {
            logger.debug("Progress cache hit for \(type.id)")
            return cached
        }

        // Cache expired or missing — repopulate all progress values
        logger.debug("Progress cache miss — rebuilding cache for all achievements")
        progressCache.removeAll()
        progressCacheTimestamp = now

        let result = computeProgress(for: type, entryStore: entryStore, goalStore: goalStore)
        if let result {
            progressCache[type.id] = result
        }

        // Pre-warm cache for other types to avoid repeated rebuilds
        for otherType in AchievementType.allCases where otherType.id != type.id {
            if let otherResult = computeProgress(for: otherType, entryStore: entryStore, goalStore: goalStore) {
                progressCache[otherType.id] = otherResult
            }
        }

        logger.debug("Progress cache rebuilt with \(self.progressCache.count) entries")
        return result
    }

    // MARK: - Helper Methods

    /// 标记用户已使用照片对比
    func markPhotoCompareUsed() {
        UserDefaults.standard.set(true, forKey: "hasUsedPhotoCompare")
        logger.info("Marked photo compare as used")
    }

    /// 标记用户已分享
    func markShared() {
        UserDefaults.standard.set(true, forKey: "hasSharedFirst")
        logger.info("Marked first share")
    }

    /// 标记用户已导出数据
    func markDataExported() {
        UserDefaults.standard.set(true, forKey: "hasExportedData")
        logger.info("Marked data exported")
    }

    /// 标记用户已设置提醒
    func markReminderSet() {
        UserDefaults.standard.set(true, forKey: "hasSetReminder")
        logger.info("Marked reminder set")
    }

    /// 检查是否达到体重减少百分比
    private func hasAchievedWeightLoss(entryStore: BodyEntryStore, percentage: Double) -> Bool {
        guard let startWeight = entryStore.startValue(for: .weight),
              let currentWeight = entryStore.latestValue(for: .weight),
              startWeight > 0 else { return false }

        let loss = (startWeight - currentWeight) / startWeight * 100
        return loss >= percentage
    }

    /// 获取体重减少进度
    private func weightLossProgress(entryStore: BodyEntryStore, percentage: Double) -> (current: Int, target: Int) {
        guard let startWeight = entryStore.startValue(for: .weight),
              let currentWeight = entryStore.latestValue(for: .weight),
              startWeight > 0 else { return (0, Int(percentage)) }

        let loss = (startWeight - currentWeight) / startWeight * 100
        let current = max(0, Int(loss))
        return (current, Int(percentage))
    }

    /// 检查是否达到体脂减少百分比
    private func hasAchievedBodyFatLoss(entryStore: BodyEntryStore, percentage: Double) -> Bool {
        guard let startBodyFat = entryStore.startValue(for: .bodyFat),
              let currentBodyFat = entryStore.latestValue(for: .bodyFat),
              startBodyFat > 0 else { return false }

        let loss = (startBodyFat - currentBodyFat) / startBodyFat * 100
        return loss >= percentage
    }

    /// 获取体脂减少进度
    private func bodyFatLossProgress(entryStore: BodyEntryStore, percentage: Double) -> (current: Int, target: Int) {
        guard let startBodyFat = entryStore.startValue(for: .bodyFat),
              let currentBodyFat = entryStore.latestValue(for: .bodyFat),
              startBodyFat > 0 else { return (0, Int(percentage)) }

        let loss = (startBodyFat - currentBodyFat) / startBodyFat * 100
        let current = max(0, Int(loss))
        return (current, Int(percentage))
    }

    /// 检查是否一周满勤
    private func hasPerfectWeek(entryStore: BodyEntryStore) -> Bool {
        let calendar = Calendar.current
        let today = Date()

        // Get entries from the past 7 days
        var hasEntryForDay = [Int: Bool]()
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
                hasEntryForDay[dayOfYear] = false
            }
        }

        // Check if we have entries for each day
        for entry in entryStore.entries {
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: entry.recordedAt) ?? 0
            if hasEntryForDay[dayOfYear] != nil {
                hasEntryForDay[dayOfYear] = true
            }
        }

        // All days must have entries
        return hasEntryForDay.values.allSatisfy { $0 }
    }

    /// 检查是否一月满勤
    private func hasPerfectMonth(entryStore: BodyEntryStore) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30

        // Get entries from this month
        let thisMonthEntries = entryStore.entries.filter {
            calendar.isDate($0.recordedAt, equalTo: today, toGranularity: .month)
        }

        // Check unique days
        var daysWithEntry = Set<Int>()
        for entry in thisMonthEntries {
            let day = calendar.component(.day, from: entry.recordedAt)
            daysWithEntry.insert(day)
        }

        return daysWithEntry.count >= daysInMonth
    }

    // MARK: - Cache Invalidation

    /// Invalidate the progress cache, forcing fresh computation on next access.
    func invalidateProgressCache() {
        progressCache.removeAll()
        progressCacheTimestamp = .distantPast
        logger.debug("Progress cache invalidated")
    }

    /// Reset the check throttle so the next call to `checkAndUnlockAchievements` will execute immediately.
    func resetCheckThrottle() {
        lastCheckTimestamp = .distantPast
        logger.debug("Check throttle reset")
    }

    // MARK: - Private Computation

    /// Raw progress computation without cache interaction.
    private func computeProgress(
        for type: AchievementType,
        entryStore: BodyEntryStore,
        goalStore: GoalStore
    ) -> (current: Int, target: Int)? {
        switch type {
        // 连续记录
        case .streak3:
            return (entryStore.currentStreak, 3)
        case .streak7:
            return (entryStore.currentStreak, 7)
        case .streak14:
            return (entryStore.currentStreak, 14)
        case .streak30:
            return (entryStore.currentStreak, 30)
        case .streak60:
            return (entryStore.currentStreak, 60)
        case .streak100:
            return (entryStore.currentStreak, 100)

        // 数据量
        case .records10:
            return (entryStore.entries.count, 10)
        case .records50:
            return (entryStore.entries.count, 50)
        case .records100:
            return (entryStore.entries.count, 100)
        case .records365:
            return (entryStore.entries.count, 365)

        // 照片
        case .photoFirst:
            return (min(entryStore.photoCount, 1), 1)
        case .photos10:
            return (entryStore.photoCount, 10)
        case .photos30:
            return (entryStore.photoCount, 30)
        case .photoCompare:
            return (entryStore.hasUsedPhotoCompare ? 1 : 0, 1)

        // 目标
        case .goalFirst:
            return (min(goalStore.goals.count, 1), 1)
        case .goalComplete:
            let completedCount = goalStore.goals.filter { $0.isAchieved }.count
            return (min(completedCount, 1), 1)
        case .goals5:
            let completedCount = goalStore.goals.filter { $0.isAchieved }.count
            return (completedCount, 5)
        case .weightLoss5:
            let (current, target) = weightLossProgress(entryStore: entryStore, percentage: 5)
            return (current, target)
        case .bodyFatLoss5:
            let (current, target) = bodyFatLossProgress(entryStore: entryStore, percentage: 5)
            return (current, target)

        // 里程碑
        case .weekPerfect:
            return (hasPerfectWeek(entryStore: entryStore) ? 1 : 0, 1)
        case .monthPerfect:
            return (hasPerfectMonth(entryStore: entryStore) ? 1 : 0, 1)
        case .shareFirst:
            return (UserDefaults.standard.bool(forKey: "hasSharedFirst") ? 1 : 0, 1)
        case .exportData:
            return (UserDefaults.standard.bool(forKey: "hasExportedData") ? 1 : 0, 1)
        case .reminderSet:
            return (UserDefaults.standard.bool(forKey: "hasSetReminder") ? 1 : 0, 1)
        }
    }
}
