// GoalStore.swift
// 目标数据管理

import Foundation
import SwiftUI
import os.log

@MainActor
class GoalStore: ObservableObject {
    @Published var goals: [GoalModel] = []

    private static let logger = Logger(subsystem: "com.pangtong.formlog", category: "GoalStore")

    private static let storeURL: URL = {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fallbackDir = FileManager.default.temporaryDirectory
        let baseURL = docsDir ?? fallbackDir
        return baseURL.appendingPathComponent("goals.json")
    }()

    init() {
        load()
    }

    // MARK: - CRUD

    @discardableResult
    func addGoal(_ goal: GoalModel) -> GoalModel {
        goals.append(goal)
        save()
        return goal
    }

    func updateGoal(_ goal: GoalModel) {
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[idx] = goal
        save()
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        save()
    }

    func markAchieved(id: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[idx].achievedAt = Date()
        save()
        // Send achievement notification
        let metricName = goals[idx].metricType.displayName
        NotificationManager.shared.sendGoalAchievedNotification(metricName: metricName)
    }

    // MARK: - Queries

    var activeGoals: [GoalModel] {
        goals.filter { !$0.isAchieved }
    }

    var achievedGoals: [GoalModel] {
        goals.filter { $0.isAchieved }
    }

    func activeGoal(for type: BodyMetricType) -> GoalModel? {
        activeGoals.first { $0.metricType == type }
    }

    // MARK: - Auto-check achievement
    func checkAndMarkAchieved(using entryStore: BodyEntryStore) {
        for goal in activeGoals {
            guard let current = entryStore.latestValue(for: goal.metricType) else { continue }
            if goal.isReached(currentValue: current) {
                markAchieved(id: goal.id)
            }
        }
    }

    // MARK: - Validation

    /// Validates a goal before persisting. Returns nil if valid, or a descriptive error string.
    private func validate(_ goal: GoalModel) -> String? {
        // targetValue must be > 0
        guard goal.targetValue > 0 else {
            return "Goal validation failed: targetValue (\(goal.targetValue)) must be > 0"
        }

        // targetValue must fall within the metric's valid range
        let range = goal.metricType.validRange
        guard range.contains(goal.targetValue) else {
            return "Goal validation failed: targetValue (\(goal.targetValue)) is outside valid range \(range.lowerBound)...\(range.upperBound) for metric \(goal.metricType.rawValue)"
        }

        return nil
    }

    /// Filters out any invalid goals from the loaded array and logs warnings.
    private func sanitizeGoals(_ decoded: [GoalModel]) -> [GoalModel] {
        var valid: [GoalModel] = []
        for goal in decoded {
            if let reason = validate(goal) {
                Self.logger.warning("Dropping corrupted goal (id=\(goal.id.uuidString)): \(reason)")
            } else {
                valid.append(goal)
            }
        }
        return valid
    }

    // MARK: - Persistence

    func save() {
        // Validate all goals before encoding
        for goal in goals {
            if let reason = validate(goal) {
                Self.logger.error("Aborting save: invalid goal detected (id=\(goal.id.uuidString)). \(reason)")
                // Remove the invalid goal to prevent persistent corruption
                goals.removeAll { $0.id == goal.id }
            }
        }
        // 立即保存，不使用延迟防抖，避免 App 被杀死时数据丢失
        performSave()
    }

    private func performSave() {
        do {
            let data = try JSONEncoder().encode(goals)
            try data.write(to: Self.storeURL, options: [.atomic, .completeFileProtection])
        } catch {
            Self.logger.error("Save error: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.storeURL.path) else {
            // No stored file yet — that's fine, start empty
            goals = []
            return
        }

        do {
            let data = try Data(contentsOf: Self.storeURL)
            let decoded = try JSONDecoder().decode([GoalModel].self, from: data)

            // Validate every decoded goal; drop any that are corrupted
            let sanitized = sanitizeGoals(decoded)

            if sanitized.count != decoded.count {
                let dropped = decoded.count - sanitized.count
                Self.logger.warning("Load warning: dropped \(dropped) invalid goal(s) from persisted data. Starting with \(sanitized.count) valid goal(s).")
                // Overwrite with sanitized set so future loads are clean
                goals = sanitized
                performSave()
            } else {
                goals = decoded
            }
        } catch {
            Self.logger.error("Load error: data is corrupted and could not be decoded. \(error.localizedDescription). Starting fresh with empty data.")

            // Backup corrupted file for potential manual recovery
            let backupURL = Self.storeURL.deletingPathExtension().appendingPathExtension("backup.json")
            do {
                try FileManager.default.createDirectory(
                    at: backupURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.copyItem(at: Self.storeURL, to: backupURL)
                Self.logger.info("Corrupted file backed up to: \(backupURL.path)")
            } catch {
                Self.logger.error("Failed to create backup of corrupted file: \(error.localizedDescription)")
            }

            // Delete the corrupted file so the next launch starts clean
            do {
                try FileManager.default.removeItem(at: Self.storeURL)
            } catch {
                Self.logger.error("Failed to remove corrupted file: \(error.localizedDescription)")
            }

            goals = []
        }
    }
}
