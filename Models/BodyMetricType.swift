// BodyMetricType.swift
// 身体指标类型定义

import Foundation
import SwiftUI

/// 支持记录的身体指标类型
enum BodyMetricType: String, CaseIterable, Codable, Identifiable {
    // MARK: - 主要指标
    case weight = "weight"
    case bodyFat = "bodyFat"
    case muscleMass = "muscleMass"
    case bmi = "bmi"

    // MARK: - 围度（cm）
    case waist = "waist"
    case hip = "hip"
    case chest = "chest"
    case leftArm = "leftArm"
    case rightArm = "rightArm"
    case leftThigh = "leftThigh"
    case rightThigh = "rightThigh"
    case neck = "neck"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight: return L10n.string("体重")
        case .bodyFat: return L10n.string("体脂率")
        case .muscleMass: return L10n.string("肌肉量")
        case .bmi: return L10n.string("BMI")
        case .waist: return L10n.string("腰围")
        case .hip: return L10n.string("臀围")
        case .chest: return L10n.string("胸围")
        case .leftArm: return L10n.string("左臂围")
        case .rightArm: return L10n.string("右臂围")
        case .leftThigh: return L10n.string("左腿围")
        case .rightThigh: return L10n.string("右腿围")
        case .neck: return L10n.string("颈围")
        }
    }

    var unit: String {
        switch self {
        case .weight, .muscleMass: return "kg"
        case .bodyFat: return "%"
        case .bmi: return ""
        case .waist, .hip, .chest, .leftArm, .rightArm, .leftThigh, .rightThigh, .neck: return "cm"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .bodyFat: return "drop.fill"
        case .muscleMass: return "figure.strengthtraining.traditional"
        case .bmi: return "chart.bar.fill"
        case .waist: return "oval"
        case .hip: return "oval.fill"
        case .chest: return "heart.fill"
        case .leftArm, .rightArm: return "figure.arms.open"
        case .leftThigh, .rightThigh: return "figure.walk"
        case .neck: return "person.fill"
        }
    }

    var category: MetricCategory {
        switch self {
        case .weight, .bodyFat, .muscleMass, .bmi: return .primary
        default: return .measurement
        }
    }
    
    /// 指标对应的颜色
    var color: Color {
        switch self {
        case .weight: return .formlogPrimary      // Green #30D158
        case .bodyFat: return .formlogBodyFat      // Blue #0A84FF
        case .muscleMass: return .formlogMuscle    // Orange #FF9F0A
        case .bmi: return .formlogBMI              // Red #FF453A
        case .waist: return .formlogWaist          // Purple #BF5AF2
        case .hip: return .formlogWaist            // Purple (same as waist)
        case .chest: return .formlogChest         // Cyan #64D2FF
        case .leftArm, .rightArm: return .formlogMuscle  // Orange
        case .leftThigh, .rightThigh: return .formlogBodyFat  // Blue
        case .neck: return .formlogBMI             // Red
        }
    }

    /// 合理值范围（用于输入校验），kg/cm/%
    var validRange: ClosedRange<Double> {
        switch self {
        case .weight: return 20...300
        case .bodyFat: return 1...70
        case .muscleMass: return 10...150
        case .bmi: return 10...80
        case .waist: return 40...200
        case .hip: return 50...200
        case .chest: return 50...200
        case .leftArm, .rightArm: return 15...80
        case .leftThigh, .rightThigh: return 25...120
        case .neck: return 20...70
        }
    }

    enum MetricCategory: String {
        case primary = "核心指标"
        case measurement = "围度测量"

        var localizedName: String {
            L10n.string(rawValue)
        }
    }
}
