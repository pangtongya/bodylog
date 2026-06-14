// Achievement.swift
// 成就/里程碑模型

import Foundation

/// 成就类型枚举
enum AchievementType: String, CaseIterable, Codable, Identifiable {
    case streak3 = "streak_3"       // 连续记录3天
    case streak7 = "streak_7"       // 连续记录7天
    case streak14 = "streak_14"     // 连续记录14天
    case streak30 = "streak_30"     // 连续记录30天
    case records10 = "records_10"   // 记录10条数据
    case records50 = "records_50"   // 记录50条数据
    case records100 = "records_100" // 记录100条数据
    case photoFirst = "photo_first" // 第一张照片
    case photos10 = "photos_10"     // 10张照片
    case goalComplete = "goal_complete" // 完成首个目标

    var id: String { rawValue }

    /// 成就显示信息
    var displayName: String {
        switch self {
        case .streak3: return "初露锋芒"
        case .streak7: return "一周坚持"
        case .streak14: return "两周毅力"
        case .streak30: return "月度达人"
        case .records10: return "数据新手"
        case .records50: return "数据积累"
        case .records100: return "百条记录"
        case .photoFirst: return "首次留影"
        case .photos10: return "摄影爱好者"
        case .goalComplete: return "目标达成"
        }
    }

    /// 成就描述
    var description: String {
        switch self {
        case .streak3: return "连续记录身体数据3天"
        case .streak7: return "连续记录身体数据7天"
        case .streak14: return "连续记录身体数据14天"
        case .streak30: return "连续记录身体数据30天"
        case .records10: return "累计记录10条身体数据"
        case .records50: return "累计记录50条身体数据"
        case .records100: return "累计记录100条身体数据"
        case .photoFirst: return "拍摄第一张形体照片"
        case .photos10: return "累计拍摄10张形体照片"
        case .goalComplete: return "完成第一个目标"
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .streak3, .streak7, .streak14, .streak30:
            return "flame.fill"
        case .records10, .records50, .records100:
            return "chart.bar.fill"
        case .photoFirst, .photos10:
            return "camera.fill"
        case .goalComplete:
            return "trophy.fill"
        }
    }

    /// 成就分类
    var category: Category {
        switch self {
        case .streak3, .streak7, .streak14, .streak30:
            return .consistency
        case .records10, .records50, .records100:
            return .volume
        case .photoFirst, .photos10:
            return .photo
        case .goalComplete:
            return .goal
        }
    }

    enum Category: String, CaseIterable {
        case consistency = "坚持记录"
        case volume = "数据积累"
        case photo = "照片记录"
        case goal = "目标达成"
    }
}

/// 单个成就实例（记录解锁时间）
struct Achievement: Identifiable, Codable, Equatable {
    let id: String           // AchievementType.rawValue
    let unlockedAt: Date     // 解锁时间
    let type: AchievementType

    init(type: AchievementType) {
        self.type = type
        self.id = type.rawValue
        self.unlockedAt = Date()
    }
}
