# BodyLog 项目记忆

## 项目概述
- **路径**: `/Users/pangtong/BodyLog`
- **技术栈**: SwiftUI + iOS 16.0+（project.yml设为16.0），xcodegen，StoreKit 2
- **Bundle ID**: com.pangtong.bodylog
- **开发者**: 庞通 (pangtong)
- **产品定位**: 隐私优先的身体数据记录App，一次性购买¥12

## 架构
- **Models**: AppState, BodyEntry, BodyMetricType, GoalModel
- **Stores**: BodyEntryStore, GoalStore (ObservableObject, @MainActor)
- **Views**: ContentView(5个Tab) → HomeView/TrendView/PhotoCompareView/GoalsView/SettingsView
- **Managers**: NotificationManager, PurchaseManager, PhotoManager
- **数据格式**: JSON本地存储 + 照片文件存储(Documents/BodyLogPhotos/)

## 关键设计决策
1. 照片存储：使用PhotoManager存Documents目录，JSON只存photoFilename（向后兼容旧photoData）
2. 数据保存：立即保存（无延迟），避免App被杀死时丢失
3. Pro功能限制：照片对比、CSV导入/导出、无限目标、每日提醒
4. Onboarding强调4个价值点：隐私优先/一次性购买/照片对比独有/趋势分析

## Git状态
- 无远程仓库配置（需手动添加）
- 7次提交（截至2026-06-14）

## 已知注意事项
- SettingsView有main actor隔离警告（preexisting）
- bodylogIncrease/bodylogWarning颜色定义未使用但保留（有语义意义）
