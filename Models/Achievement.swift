// Achievement.swift
// 成就/里程碑模型

import Foundation

/// 成就类型枚举
enum AchievementType: String, CaseIterable, Codable, Identifiable {
    case streak3 = "streak_3"
    case streak7 = "streak_7"
    case streak14 = "streak_14"
    case streak30 = "streak_30"
    case streak60 = "streak_60"
    case streak100 = "streak_100"
    case records10 = "records_10"
    case records50 = "records_50"
    case records100 = "records_100"
    case records200 = "records_200"
    case records500 = "records_500"
    case photoFirst = "photo_first"
    case photos10 = "photos_10"
    case photos30 = "photos_30"
    case photos50 = "photos_50"
    case goalComplete = "goal_complete"
    case goalComplete3 = "goal_complete_3"
    case multiMetric3 = "multi_metric_3"
    case multiMetric5 = "multi_metric_5"
    case perfectWeek = "perfect_week"
    case monthlyMaster = "monthly_master"
    case weightLost5 = "weight_lost_5"
    case weightLost10 = "weight_lost_10"
    case bodyFatLost3 = "bodyfat_lost_3"
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case shareFirst = "share_first"
    case backupFirst = "backup_first"
    case proUser = "pro_user"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streak3: return L10n.string("初露锋芒")
        case .streak7: return L10n.string("一周坚持")
        case .streak14: return L10n.string("两周毅力")
        case .streak30: return L10n.string("月度达人")
        case .streak60: return L10n.string("双月战士")
        case .streak100: return L10n.string("百日传说")
        case .records10: return L10n.string("数据新手")
        case .records50: return L10n.string("数据积累")
        case .records100: return L10n.string("百条记录")
        case .records200: return L10n.string("双百成就")
        case .records500: return L10n.string("数据大师")
        case .photoFirst: return L10n.string("首次留影")
        case .photos10: return L10n.string("摄影爱好者")
        case .photos30: return L10n.string("月度摄影师")
        case .photos50: return L10n.string("蜕变记录者")
        case .goalComplete: return L10n.string("目标达成")
        case .goalComplete3: return L10n.string("三目标征服者")
        case .multiMetric3: return L10n.string("多面手")
        case .multiMetric5: return L10n.string("全面追踪")
        case .perfectWeek: return L10n.string("完美一周")
        case .monthlyMaster: return L10n.string("月度模范")
        case .weightLost5: return L10n.string("轻装上阵")
        case .weightLost10: return L10n.string("脱胎换骨")
        case .bodyFatLost3: return L10n.string("脂肪杀手")
        case .earlyBird: return L10n.string("早起的鸟儿")
        case .nightOwl: return L10n.string("夜猫子")
        case .shareFirst: return L10n.string("分享达人")
        case .backupFirst: return L10n.string("数据守护者")
        case .proUser: return L10n.string("Pro 会员")
        }
    }

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
        case .records200: return L10n.string("累计记录200条身体数据")
        case .records500: return L10n.string("累计记录500条身体数据")
        case .photoFirst: return L10n.string("拍摄第一张形体照片")
        case .photos10: return L10n.string("累计拍摄10张形体照片")
        case .photos30: return L10n.string("累计拍摄30张形体照片")
        case .photos50: return L10n.string("累计拍摄50张形体照片")
        case .goalComplete: return L10n.string("完成第一个目标")
        case .goalComplete3: return L10n.string("完成3个不同的目标")
        case .multiMetric3: return L10n.string("同时追踪3个及以上指标")
        case .multiMetric5: return L10n.string("同时追踪5个及以上指标")
        case .perfectWeek: return L10n.string("连续7天每天都有记录")
        case .monthlyMaster: return L10n.string("单月记录达到25天")
        case .weightLost5: return L10n.string("累计减重达到5公斤")
        case .weightLost10: return L10n.string("累计减重达到10公斤")
        case .bodyFatLost3: return L10n.string("体脂率下降3%")
        case .earlyBird: return L10n.string("在早上6-8点记录身体数据")
        case .nightOwl: return L10n.string("在晚上10点后记录身体数据")
        case .shareFirst: return L10n.string("第一次分享你的记录")
        case .backupFirst: return L10n.string("创建第一个手动备份")
        case .proUser: return L10n.string("升级到 FormLog Pro")
        }
    }

    var icon: String {
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100:
            return "flame.fill"
        case .records10, .records50, .records100, .records200, .records500:
            return "chart.bar.fill"
        case .photoFirst, .photos10, .photos30, .photos50:
            return "camera.fill"
        case .goalComplete, .goalComplete3:
            return "trophy.fill"
        case .multiMetric3, .multiMetric5:
            return "person.badge.plus"
        case .perfectWeek:
            return "calendar.badge.checkmark"
        case .monthlyMaster:
            return "calendar.circle.fill"
        case .weightLost5, .weightLost10:
            return "scalemass.fill"
        case .bodyFatLost3:
            return "drop.fill"
        case .earlyBird:
            return "sunrise.fill"
        case .nightOwl:
            return "moon.stars.fill"
        case .shareFirst:
            return "square.and.arrow.up.fill"
        case .backupFirst:
            return "archivebox.fill"
        case .proUser:
            return "sparkles"
        }
    }

    var category: Category {
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100, .perfectWeek, .monthlyMaster:
            return .consistency
        case .records10, .records50, .records100, .records200, .records500:
            return .volume
        case .photoFirst, .photos10, .photos30, .photos50:
            return .photo
        case .goalComplete, .goalComplete3, .weightLost5, .weightLost10, .bodyFatLost3:
            return .goal
        case .multiMetric3, .multiMetric5, .earlyBird, .nightOwl, .shareFirst, .backupFirst, .proUser:
            return .special
        }
    }

    enum Category: String, CaseIterable {
        case consistency = "坚持记录"
        case volume = "数据积累"
        case photo = "照片记录"
        case goal = "目标达成"
        case special = "特殊成就"

        var localizedName: String {
            L10n.string(rawValue)
        }
    }

    var rarity: Rarity {
        switch self {
        case .streak3, .records10, .photoFirst, .multiMetric3, .earlyBird, .nightOwl:
            return .common
        case .streak7, .streak14, .records50, .photos10, .goalComplete, .perfectWeek, .shareFirst, .backupFirst:
            return .rare
        case .streak30, .records100, .photos30, .goalComplete3, .multiMetric5, .monthlyMaster, .weightLost5, .proUser:
            return .epic
        case .streak60, .streak100, .records200, .records500, .photos50, .weightLost10, .bodyFatLost3:
            return .legendary
        }
    }

    enum Rarity: String, CaseIterable {
        case common = "普通"
        case rare = "稀有"
        case epic = "史诗"
        case legendary = "传说"

        var color: Color {
            switch self {
            case .common: return .gray
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .orange
            }
        }

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
