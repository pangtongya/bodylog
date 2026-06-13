// GoalModel.swift
// 目标数据模型

import Foundation

struct GoalModel: Identifiable, Codable, Equatable {
    var id: UUID
    var metricType: BodyMetricType
    var targetValue: Double
    var direction: Direction
    var createdAt: Date
    var achievedAt: Date?

    init(
        id: UUID = UUID(),
        metricType: BodyMetricType,
        targetValue: Double,
        direction: Direction,
        createdAt: Date = Date(),
        achievedAt: Date? = nil
    ) {
        self.id = id
        self.metricType = metricType
        self.targetValue = targetValue
        self.direction = direction
        self.createdAt = createdAt
        self.achievedAt = achievedAt
    }

    /// 目标方向
    enum Direction: String, Codable {
        case decrease = "decrease"  // 减少（减脂/减重）
        case increase = "increase"  // 增加（增肌）
        case maintain = "maintain"  // 维持

        var displayName: String {
            switch self {
            case .decrease: return "减少到"
            case .increase: return "增加到"
            case .maintain: return "维持在"
            }
        }

        var icon: String {
            switch self {
            case .decrease: return "arrow.down.circle.fill"
            case .increase: return "arrow.up.circle.fill"
            case .maintain: return "equal.circle.fill"
            }
        }
    }

    var isAchieved: Bool { achievedAt != nil }

    /// 计算进度 0...1，基于当前值和初始值
    func progress(currentValue: Double, startValue: Double) -> Double {
        guard startValue != targetValue else { return isAchieved ? 1.0 : 0.0 }
        switch direction {
        case .decrease:
            let total = startValue - targetValue
            guard total > 0 else { return 1.0 }
            let done = startValue - currentValue
            return max(0, min(1, done / total))
        case .increase:
            let total = targetValue - startValue
            guard total > 0 else { return 1.0 }
            let done = currentValue - startValue
            return max(0, min(1, done / total))
        case .maintain:
            let diff = abs(currentValue - targetValue)
            return diff < 1.0 ? 1.0 : 0.0
        }
    }

    /// 是否已达成目标值
    func isReached(currentValue: Double) -> Bool {
        switch direction {
        case .decrease: return currentValue <= targetValue
        case .increase: return currentValue >= targetValue
        case .maintain: return abs(currentValue - targetValue) < 0.5
        }
    }
}
