// AchievementManager.swift
// 成就系统管理器 - 检查和解锁成就

import Foundation

/// 成就管理器 - 单例模式
@MainActor
final class AchievementManager {

    static let shared = AchievementManager()

    private init() {}

    // MARK: - Public API

    /// 检查并解锁新成就（在每次保存数据后调用）
    /// - Returns: 新解锁的成就列表（用于显示通知）
    @discardableResult
    func checkAndUnlockAchievements(
        entryStore: BodyEntryStore,
        goalStore: GoalStore,
        existingAchievements: [Achievement]
    ) -> [Achievement] {
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
            }
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

        // 数据量成就
        case .records10:
            return entryStore.entries.count >= 10
        case .records50:
            return entryStore.entries.count >= 50
        case .records100:
            return entryStore.entries.count >= 100

        // 照片成就
        case .photoFirst:
            return entryStore.photoCount > 0
        case .photos10:
            return entryStore.photoCount >= 10

        // 目标成就
        case .goalComplete:
            return goalStore.goals.contains { $0.isAchieved }
        }
    }

    // MARK: - Progress Tracking

    /// 获取某个成就类型的当前进度（用于进度条显示）
    func progress(for type: AchievementType, entryStore: BodyEntryStore, goalStore: GoalStore) -> (current: Int, target: Int)? {
        switch type {
        case .streak3:
            return (entryStore.currentStreak, 3)
        case .streak7:
            return (entryStore.currentStreak, 7)
        case .streak14:
            return (entryStore.currentStreak, 14)
        case .streak30:
            return (entryStore.currentStreak, 30)
        case .records10:
            return (entryStore.entries.count, 10)
        case .records50:
            return (entryStore.entries.count, 50)
        case .records100:
            return (entryStore.entries.count, 100)
        case .photoFirst:
            return (min(entryStore.photoCount, 1), 1)
        case .photos10:
            return (entryStore.photoCount, 10)
        case .goalComplete:
            let completedCount = goalStore.goals.filter { $0.isAchieved }.count
            return (min(completedCount, 1), 1)
        }
    }
}
