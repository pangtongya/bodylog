# BodyLog 项目记忆

## 项目概述
- **路径**: `/Users/pangtong/BodyLog`
- **技术栈**: SwiftUI + iOS 16.0+（project.yml设为16.0），xcodegen，StoreKit 2
- **Bundle ID**: com.pangtong.bodylog
- **开发者**: 庞通 (pangtong)
- **产品定位**: 隐私优先的身体数据记录App，一次性购买¥12
- **优化状态**: 16/16问题全部解决 (2026-06-14)

## 架构
- **Models**: AppState, BodyEntry, BodyMetricType, GoalModel, Achievement
- **Stores**: BodyEntryStore, GoalStore (ObservableObject, @MainActor)
- **Views**: ContentView(5个Tab) → HomeView/TrendView/PhotoCompareView/GoalsView/SettingsView
  - AchievementView: 成就展示页 + 解锁通知横幅
  - ShareCardView: 数据卡片分享视图
- **Managers**: NotificationManager, PurchaseManager, PhotoManager, AchievementManager(@MainActor)
- **数据格式**: JSON本地存储 + 照片文件存储(Documents/BodyLogPhotos/) + 成就存储(AppState.achievements)

## 关键设计决策
1. 照片存储：使用PhotoManager存Documents目录，JSON只存photoFilename（向后兼容旧photoData）
2. 数据保存：立即保存（无延迟），避免App被杀死时丢失
3. Pro功能限制：照片对比、CSV导入/导出、无限目标、每日提醒
4. Onboarding强调差异化："不同于Apple健康" + ¥12买断明确价格
5. 成就系统：10种成就类型，LogEntryView保存后自动检查解锁
6. 分享功能：ShareCardView生成数据卡片图片，隐私优先用户主动选择

## Git状态
- 无远程仓库配置（需手动添加）
- 8次提交（截至2026-06-14 第三轮完成）

## 已知注意事项
- SettingsView有main actor隔离警告（preexisting）
- ✅ 已清理未使用颜色定义（bodylogSecondary/Increase/Warning已删除）
