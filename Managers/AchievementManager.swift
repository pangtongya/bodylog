import Foundation

@MainActor
final class AchievementManager {

    static let shared = AchievementManager()

    private init() {}

    @discardableResult
    func checkAndUnlockAchievements(
        entryStore: BodyEntryStore,
        goalStore: GoalStore,
        appState: AppState,
        existingAchievements: [Achievement]
    ) -> [Achievement] {
        var newAchievements: [Achievement] = []
        let unlockedIds = Set(existingAchievements.map { $0.id })

        for type in AchievementType.allCases {
            if unlockedIds.contains(type.id) { continue }

            if isUnlocked(type: type, entryStore: entryStore, goalStore: goalStore, appState: appState) {
                let achievement = Achievement(type: type)
                newAchievements.append(achievement)
            }
        }

        if newAchievements.count > 3 {
            return Array(newAchievements.prefix(3))
        }

        return newAchievements
    }

    func isUnlocked(
        type: AchievementType,
        entryStore: BodyEntryStore,
        goalStore: GoalStore,
        appState: AppState
    ) -> Bool {
        switch type {
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

        case .records10:
            return entryStore.entries.count >= 10
        case .records50:
            return entryStore.entries.count >= 50
        case .records100:
            return entryStore.entries.count >= 100
        case .records200:
            return entryStore.entries.count >= 200
        case .records500:
            return entryStore.entries.count >= 500

        case .photoFirst:
            return entryStore.photoCount > 0
        case .photos10:
            return entryStore.photoCount >= 10
        case .photos30:
            return entryStore.photoCount >= 30
        case .photos50:
            return entryStore.photoCount >= 50

        case .goalComplete:
            return goalStore.goals.contains { $0.isAchieved }
        case .goalComplete3:
            return goalStore.goals.filter { $0.isAchieved }.count >= 3

        case .multiMetric3:
            return appState.enabledMetrics.count >= 3
        case .multiMetric5:
            return appState.enabledMetrics.count >= 5

        case .perfectWeek:
            return entryStore.currentStreak >= 7
        case .monthlyMaster:
            let calendar = Calendar.current
            let now = Date()
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let monthEntries = entryStore.entries.filter { $0.recordedAt >= monthStart }
            let uniqueDays = Set(monthEntries.map { calendar.startOfDay(for: $0.recordedAt) })
            return uniqueDays.count >= 25

        case .weightLost5:
            return totalWeightChange(entryStore: entryStore) <= -5
        case .weightLost10:
            return totalWeightChange(entryStore: entryStore) <= -10
        case .bodyFatLost3:
            return totalBodyFatChange(entryStore: entryStore) <= -3

        case .earlyBird:
            guard let latest = entryStore.latestEntry else { return false }
            let hour = Calendar.current.component(.hour, from: latest.recordedAt)
            return hour >= 6 && hour <= 8
        case .nightOwl:
            guard let latest = entryStore.latestEntry else { return false }
            let hour = Calendar.current.component(.hour, from: latest.recordedAt)
            return hour >= 22 || hour <= 2
        case .shareFirst:
            return UserDefaults.standard.bool(forKey: "hasSharedBefore")
        case .backupFirst:
            return UserDefaults.standard.bool(forKey: "hasCreatedBackup")
        case .proUser:
            return appState.isPro
        }
    }

    private func totalWeightChange(entryStore: BodyEntryStore) -> Double {
        let entries = entryStore.entries.sorted(by: { $0.recordedAt < $1.recordedAt })
        guard let first = entries.first?.metrics[.weight],
              let last = entries.last?.metrics[.weight] else { return 0 }
        return last - first
    }

    private func totalBodyFatChange(entryStore: BodyEntryStore) -> Double {
        let entries = entryStore.entries.sorted(by: { $0.recordedAt < $1.recordedAt })
        guard let first = entries.first?.metrics[.bodyFat],
              let last = entries.last?.metrics[.bodyFat] else { return 0 }
        return last - first
    }

    func progress(for type: AchievementType, entryStore: BodyEntryStore, goalStore: GoalStore, appState: AppState) -> (current: Int, target: Int)? {
        switch type {
        case .streak3: return (entryStore.currentStreak, 3)
        case .streak7: return (entryStore.currentStreak, 7)
        case .streak14: return (entryStore.currentStreak, 14)
        case .streak30: return (entryStore.currentStreak, 30)
        case .streak60: return (entryStore.currentStreak, 60)
        case .streak100: return (entryStore.currentStreak, 100)

        case .records10: return (entryStore.entries.count, 10)
        case .records50: return (entryStore.entries.count, 50)
        case .records100: return (entryStore.entries.count, 100)
        case .records200: return (entryStore.entries.count, 200)
        case .records500: return (entryStore.entries.count, 500)

        case .photoFirst: return (min(entryStore.photoCount, 1), 1)
        case .photos10: return (entryStore.photoCount, 10)
        case .photos30: return (entryStore.photoCount, 30)
        case .photos50: return (entryStore.photoCount, 50)

        case .goalComplete:
            let completed = goalStore.goals.filter { $0.isAchieved }.count
            return (min(completed, 1), 1)
        case .goalComplete3:
            let completed = goalStore.goals.filter { $0.isAchieved }.count
            return (min(completed, 3), 3)

        case .multiMetric3: return (min(appState.enabledMetrics.count, 3), 3)
        case .multiMetric5: return (min(appState.enabledMetrics.count, 5), 5)

        case .perfectWeek: return (min(entryStore.currentStreak, 7), 7)
        case .monthlyMaster:
            let calendar = Calendar.current
            let now = Date()
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let monthEntries = entryStore.entries.filter { $0.recordedAt >= monthStart }
            let uniqueDays = Set(monthEntries.map { calendar.startOfDay(for: $0.recordedAt) })
            return (min(uniqueDays.count, 25), 25)

        case .weightLost5:
            let change = -totalWeightChange(entryStore: entryStore)
            return (max(0, min(Int(change), 5)), 5)
        case .weightLost10:
            let change = -totalWeightChange(entryStore: entryStore)
            return (max(0, min(Int(change), 10)), 10)
        case .bodyFatLost3:
            let change = -totalBodyFatChange(entryStore: entryStore)
            return (max(0, min(Int(change), 3)), 3)

        case .earlyBird, .nightOwl, .shareFirst, .backupFirst, .proUser:
            return nil
        }
    }
}
