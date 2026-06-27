// Achievement.swift
// 成就/里程碑模型

import Foundation

/// 成就类型枚举
enum AchievementType: String, CaseIterable, Codable, Identifiable {
    // MARK: - 连续记录成就
    case streak3 = "streak_3"       // 连续记录3天
    case streak7 = "streak_7"       // 连续记录7天
    case streak14 = "streak_14"     // 连续记录14天
    case streak30 = "streak_30"     // 连续记录30天
    case streak60 = "streak_60"     // 连续记录60天
    case streak100 = "streak_100"   // 连续记录100天
    
    // MARK: - 数据量成就
    case records10 = "records_10"   // 记录10条数据
    case records50 = "records_50"   // 记录50条数据
    case records100 = "records_100" // 记录100条数据
    case records365 = "records_365" // 记录365条数据
    
    // MARK: - 照片成就
    case photoFirst = "photo_first"     // 第一张照片
    case photos10 = "photos_10"         // 10张照片
    case photos30 = "photos_30"          // 30张照片
    case photoCompare = "photo_compare"  // 首次使用照片对比
    
    // MARK: - 目标成就
    case goalFirst = "goal_first"           // 设置第一个目标
    case goalComplete = "goal_complete"       // 完成首个目标
    case goals5 = "goals_5"                   // 完成5个目标
    case weightLoss5 = "weight_loss_5"       // 体重减少5%
    case bodyFatLoss5 = "bodyfat_loss_5"      // 体脂减少5%
    
    // MARK: - 里程碑成就
    case weekPerfect = "week_perfect"       // 一周满勤
    case monthPerfect = "month_perfect"       // 一月满勤
    case shareFirst = "share_first"          // 首次分享
    case exportData = "export_data"           // 首次导出数据
    case reminderSet = "reminder_set"         // 设置提醒

    var id: String { rawValue }

    /// 成就显示信息
    var displayName: String {
        switch self {
        // 连续记录
        case .streak3: return L10n.string("初露锋芒")
        case .streak7: return L10n.string("一周坚持")
        case .streak14: return L10n.string("两周毅力")
        case .streak30: return L10n.string("月度达人")
        case .streak60: return L10n.string("双月坚持")
        case .streak100: return L10n.string("百日英雄")
        
        // 数据量
        case .records10: return L10n.string("数据新手")
        case .records50: return L10n.string("数据积累")
        case .records100: return L10n.string("百条记录")
        case .records365: return L10n.string("年度数据")
        
        // 照片
        case .photoFirst: return L10n.string("首次留影")
        case .photos10: return L10n.string("摄影爱好者")
        case .photos30: return L10n.string("照片达人")
        case .photoCompare: return L10n.string("见证变化")
        
        // 目标
        case .goalFirst: return L10n.string("目标启程")
        case .goalComplete: return L10n.string("目标达成")
        case .goals5: return L10n.string("目标猎手")
        case .weightLoss5: return L10n.string("减重先锋")
        case .bodyFatLoss5: return L10n.string("降脂达人")
        
        // 里程碑
        case .weekPerfect: return L10n.string("一周满勤")
        case .monthPerfect: return L10n.string("一月满勤")
        case .shareFirst: return L10n.string("首次分享")
        case .exportData: return L10n.string("数据守护")
        case .reminderSet: return L10n.string("提醒达人")
        }
    }

    /// 成就描述
    var description: String {
        switch self {
        case .streak3: return L10n.string("连续记录身体数据3天")
        case .streak7: return L10n.string("连续记录身体数据7天")
        case .streak14: return L10n.string("连续记录身体数据14天")
        case .streak30: return L10n.string("连续记录身体数据30天")
        case .streak60: return L10n.string("连续记录身体数据60天")
        case .streak100: return L10n.string("连续记录身体数据100天")
        case .records10: return L10n.string("累计记录10条身体数据")
        case .records50: return L10n.string("累计记录50条身体数据")
        case .records100: return L10n.string("累计记录100条身体数据")
        case .records365: return L10n.string("累计记录365条身体数据")
        case .photoFirst: return L10n.string("拍摄第一张形体照片")
        case .photos10: return L10n.string("累计拍摄10张形体照片")
        case .photos30: return L10n.string("累计拍摄30张形体照片")
        case .photoCompare: return L10n.string("首次使用照片对比功能")
        case .goalFirst: return L10n.string("设置第一个健康目标")
        case .goalComplete: return L10n.string("完成第一个目标")
        case .goals5: return L10n.string("累计完成5个目标")
        case .weightLoss5: return L10n.string("体重相比初始值减少5%")
        case .bodyFatLoss5: return L10n.string("体脂率相比初始值减少5%")
        case .weekPerfect: return L10n.string("一周内每天都记录")
        case .monthPerfect: return L10n.string("一个月内每天都记录")
        case .shareFirst: return L10n.string("首次分享进度卡片")
        case .exportData: return L10n.string("首次导出CSV数据")
        case .reminderSet: return L10n.string("设置每日提醒")
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100:
            return "flame.fill"
        case .records10, .records50, .records100, .records365:
            return "chart.bar.fill"
        case .photoFirst, .photos10, .photos30:
            return "camera.fill"
        case .photoCompare:
            return "photo.stack.fill"
        case .goalFirst, .goalComplete, .goals5:
            return "trophy.fill"
        case .weightLoss5, .bodyFatLoss5:
            return "star.fill"
        case .weekPerfect, .monthPerfect:
            return "calendar.badge.checkmark"
        case .shareFirst:
            return "square.and.arrow.up.fill"
        case .exportData:
            return "arrow.down.doc.fill"
        case .reminderSet:
            return "bell.fill"
        }
    }

    /// 成就分类
    var category: Category {
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100, .weekPerfect, .monthPerfect:
            return .consistency
        case .records10, .records50, .records100, .records365:
            return .volume
        case .photoFirst, .photos10, .photos30, .photoCompare:
            return .photo
        case .goalFirst, .goalComplete, .goals5, .weightLoss5, .bodyFatLoss5:
            return .goal
        case .shareFirst, .exportData, .reminderSet:
            return .milestone
        }
    }

    enum Category: String, CaseIterable {
        case consistency = "坚持记录"
        case volume = "数据积累"
        case photo = "照片记录"
        case goal = "目标达成"
        case milestone = "里程碑"

        var localizedName: String {
            L10n.string(rawValue)
        }
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
