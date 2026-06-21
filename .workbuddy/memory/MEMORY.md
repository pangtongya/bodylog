# FormLog 项目记忆

## 项目概述
- **路径**: `/Users/pangtong/BodyLog`
- **技术栈**: SwiftUI + iOS 16.0+（project.yml设为16.0），xcodegen，StoreKit 2
- **Bundle ID**: com.pangtong.formlog
- **开发者**: 庞通 (pangtong)
- **产品定位**: 隐私优先的身体数据记录App，一次性买断
- **品牌名**: 英文 FormLog / 中文 形记
- **StoreKit Product ID**: com.pangtong.formlog.pro
- **优化状态**: 审查报告20个问题100%修复完成 (2026-06-21)

## 架构
- **Models**: AppState, BodyEntry, BodyMetricType, GoalModel, Achievement（全部含 L10n 本地化）
- **Stores**: BodyEntryStore, GoalStore (ObservableObject, @MainActor，立即保存)
- **Views**: ContentView(4个Tab) → HomeView/TrendView/GoalsView/SettingsView
  - AchievementView: 成就展示页 + 解锁通知横幅(overlay固定位置)
  - ShareCardView: 数据卡片分享视图（强制浅色模式）
  - PhotoCompareView: 照片对比（Pro功能，GeometryReader适配）
  - EntryDetailView: 记录详情页
  - OnboardingView: 3步引导
  - PaywallView: 付费墙
  - LogEntryView: 数据记录（photoWasRemoved标志位防误删）
- **Managers**: NotificationManager, PurchaseManager, PhotoManager, AchievementManager(@MainActor)
- **Utilities**: ColorExtensions(formlog品牌色), L10n(本地化工具)
- **数据格式**: JSON本地存储 + 照片文件存储(Documents/FormLogPhotos/) + 成就存储(AppState.achievements)
- **国际化**: zh-Hans + en 双语言，Localizable.strings + InfoPlist.strings

## 关键设计决策
1. 照片存储：使用PhotoManager存Documents目录，JSON只存photoFilename（向后兼容旧photoData）
2. 数据保存：立即保存（无延迟），避免App被杀死时丢失
3. Pro功能限制：照片对比、CSV导入/导出、无限目标、每日提醒
4. Onboarding强调差异化："隐私优先" + "一次买断"（不显示具体价格，Paywall动态获取）
5. 成就系统：10种成就类型，LogEntryView保存后自动检查解锁
6. 分享功能：ShareCardView生成数据卡片图片，隐私优先用户主动选择
7. 删除记录时同步删除照片文件（避免存储浪费）
8. LogEntryView取消时有确认对话框（防止误操作丢数据）
9. PhotoCompareView选中第2张照片自动进入对比模式（提升流畅度）
10. 成就通知横幅使用overlay固定在顶部（不被滚动遮挡）
11. GoalsView使用contextMenu长按删除（swipeActions仅List可用）
12. 国际化：zh-Hans + en 双语言，L10n辅助工具，Model displayName也本地化
13. FormLogApp使用@StateObject持有ObservableObject（非@State）
14. CameraPicker支持相机降级和图片方向修正
15. 编辑模式照片保护：photoWasRemoved标志位区分"主动删除"和"没碰照片"
16. 品牌色变量名：formlogPrimary/formlogAccent/formlogDecrease/formlogDanger/formlogGradient
17. 照片对比入口在首页显眼位置（非Pro显示锁图标→Paywall）

## Git状态
- 远程仓库: https://github.com/pangtongya/bodylog.git
- 25+次提交（截至2026-06-21 审查报告20个问题100%修复完成）
- 7个功能分支全部合并到main

## 已知注意事项
- SettingsView有main actor隔离警告（preexisting）
- ⚠️ xcodegen有目录组warning（已知问题，不影响功能）

## 未来版本规划 (v1.1+)
- Widget支持（主屏幕快捷记录）- P1
- iCloud同步 - P1
- PDF周报/月报 - P2
- Apple Watch配套 - P2
