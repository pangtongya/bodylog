// GoalStore.swift
// 目标数据管理

import Foundation
import SwiftUI

@MainActor
class GoalStore: ObservableObject {
    @Published var goals: [GoalModel] = []

    private static let storeURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("goals.json")
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

    // MARK: - Persistence
    
    func save() {
        // 立即保存，不使用延迟防抖，避免 App 被杀死时数据丢失
        performSave()
    }
    
    private func performSave() {
        do {
            let data = try JSONEncoder().encode(goals)
            try data.write(to: Self.storeURL)
        } catch {
            print("[GoalStore] Save error: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Self.storeURL)
            goals = try JSONDecoder().decode([GoalModel].self, from: data)
        } catch {
            goals = []
        }
    }
}
