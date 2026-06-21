# 形记 (FormLog) — 全量代码审计报告

> 审计时间：2026-06-22  
> 审计分支：fix/all-issues-from-prev  
> 审查范围：全部 31 个源文件（15 Swift 源码 + 2 Store + 4 Manager + 13 View + 工具/配置/资源/测试）  
> 总计问题数：**118 项**（CRITICAL: 9 | HIGH: 18 | MEDIUM: 52 | LOW: 39）

---

## 一、CRITICAL — 崩溃 / 数据丢失 / 安全漏洞（9 项）

### C1. 三个存储文件的 write(to:) 未使用 .atomic，崩溃时数据全部丢失

- **文件：** `AppState.swift:125`、`BodyEntryStore.swift:427`、`GoalStore.swift:85`
- **代码：** `try encoded.write(to: Self.storeURL)`
- **问题：** `Data.write(to:)` 默认非原子写入。若 App 在写入过程中被系统杀死（如后台切换时内存回收）、设备断电，JSON 文件会被截断损坏。下次启动 `load()` 解码失败，用户的全部身体数据、设置、成就、Pro 状态永久丢失。
- **修复：** 使用 `try encoded.write(to: Self.storeURL, options: .atomic)`

---

### C2. `restoreFromBackup` 静默失败且恢复后不调用 `save()`

- **文件：** `AppState.swift:175-189`
- **代码：**
```swift
func restoreFromBackup(_ data: Data) {
    guard let decoded = try? JSONDecoder().decode(CodableData.self, from: data) else { return }
    // ... 赋值 ...
    // 没有调用 save()!
}
```
- **问题：** (1) 备份数据损坏或不兼容时，`guard` 静默返回，用户以为恢复成功但实际什么都没发生；(2) 即使恢复成功，也没有调用 `save()`，数据仅存在于内存，下次启动即丢失。
- **修复：** 返回 `Bool` 或 `throws` 以便调用方显示反馈；恢复成功后立即调用 `save()`。

---

### C3. 无 Codable 持久化的 Schema 迁移机制

- **文件：** `AppState.swift:80-93`、`BodyEntryStore.swift`、`GoalStore.swift`
- **问题：** 所有持久化都使用 `Codable` 直接解码 JSON。未来版本如果新增字段（如 `notificationsEnabled: Bool`），旧版 JSON 文件缺少该字段会导致解码失败，`catch` 块静默回退到默认值 — 等于清空了用户的全部数据。文件中没有版本号，没有迁移逻辑。
- **修复：** 在 JSON 结构中加入 `schemaVersion: Int` 字段；新增字段使用可选类型或提供默认值；实现版本化迁移。

---

### C4. `fatalError` 导致 Documents 目录不可用时启动崩溃

- **文件：** `BodyEntryStore.swift:13`、`GoalStore.swift:13`、`AppState.swift:98`
- **代码：** `fatalError("[BodyEntryStore] Cannot access Documents directory")`
- **问题：** 如果沙盒 Documents 目录不可用（磁盘故障、企业 MDM 限制），App 在启动时直接崩溃，用户无法看到任何错误提示。
- **修复：** 替换为优雅降级方案，如使用 Caches 目录或临时目录，并向用户显示错误。

---

### C5. `PhotoManager` 路径遍历漏洞

- **文件：** `PhotoManager.swift:49-61`
- **代码：**
```swift
func loadPhoto(filename: String) -> Data? {
    let url = photosDirectory.appendingPathComponent(filename)
    // ...
}
```
- **问题：** `filename` 参数未校验。若值为 `../../app_state.json`，会解析到照片目录之外，可能读取或删除 App 沙盒内的任意文件。由于 `photoFilename` 存储在 `BodyEntry` 中并从 JSON 反序列化，损坏的备份导入可触发此漏洞。
- **修复：** 校验解析后的 URL 路径是否以 `photosDirectory.path` 开头，或过滤 `/` 和 `..`。

---

### C6. Streak 缓存失效仅检查 entries.count，编辑日期不触发刷新

- **文件：** `BodyEntryStore.swift:196-198`
- **代码：**
```swift
if _cachedStreakEntriesCount == entries.count, let cached = _cachedStreak {
    return cached
}
```
- **问题：** 如果用户删除一条记录再添加一条（总数不变），或修改某条记录的 `recordedAt` 日期，缓存不会失效，导致连续天数显示错误、成就解锁判断不准。
- **修复：** 使用 dirty flag 或基于日期 hash 的缓存键，在每个 mutating 方法中设置失效。

---

### C7. `EntryDetailView` 编辑后显示过期数据

- **文件：** `EntryDetailView.swift:13`
- **代码：** `let entry: BodyEntry`
- **问题：** `entry` 是值类型常量。用户点击编辑后，`LogEntryView` 通过 `entryStore.updateEntry()` 修改了数据，但 `EntryDetailView` 的本地副本仍是旧值。指标、照片、备注在编辑后不会刷新，直到返回并重新打开。
- **修复：** 改为通过 `entryID` 从 store 动态查询，或监听 store 变更。

---

### C8. `.sheet` 修饰符挂在 `if` 分支内部，视图身份切换导致展示失败

- **文件：** `EntryDetailView.swift:52-57`、`LogEntryView.swift:207-219`
- **问题：** `.sheet(isPresented:)` 附加在条件分支内的 Button 上。当 `isPro` 状态变化（如购买后），整个视图树身份改变，sheet 的展示状态可能变成孤儿节点，导致 sheet 无法弹出或无法关闭。
- **修复：** 将 `.sheet` 修饰符移到外层容器（`ScrollView` 或 `VStack`）上。

---

### C9. SettingsView 备份恢复使用 `try?` + `?? Data()` 静默吞掉错误

- **文件：** `SettingsView.swift`（备份恢复逻辑）
- **问题：** 备份文件解码失败时，使用 `try?` 静默忽略错误并用 `Data()` 代替，用户看到"恢复成功"但实际什么都没恢复。
- **修复：** 使用 `do-catch` 捕获错误并向用户显示具体失败原因。

---

## 二、HIGH — App Store 审核风险（18 项）

### H1. Pro 退款/撤销未处理：用户退款后永久保留 Pro

- **文件：** `PurchaseManager.swift:124-138`
- **问题：** `checkPurchases()` 遍历 `Transaction.currentEntitlements` 时，只在找到有效交易时设置 `isPro = true`。若用户收到退款或 Apple 撤销购买，`currentEntitlements` 不返回匹配项或 `revocationDate` 非 nil，但代码从不设置 `isPro = false`。退款用户永久保有 Pro 功能。
- **修复：** 遍历结束后默认设置 `isPro = false`；在 `Transaction.updates` 监听中也处理 `revocationDate != nil` 的情况。

---

### H2. `Transaction.updates` 静默丢弃 `.unverified` 交易

- **文件：** `PurchaseManager.swift:124-138`
- **问题：** 监听循环仅处理 `.verified` 交易。`.unverified` 交易（可能表示欺诈或越狱）被完全忽略，无日志、无用户通知。Apple 审核会检查交易处理的完整性。
- **修复：** 添加 `else` 分支记录日志并可选通知用户。

---

### H3. Pro 状态仅存储在本地 JSON，无服务端校验

- **文件：** `AppState.swift:31`、`PurchaseManager.swift:77`
- **问题：** `isPro` 是本地 JSON 文件中的布尔值。越狱设备或通过 iMazing 修改文件系统即可免费获取 Pro。虽然独立开发者常见纯客户端校验，但这很容易被绕过。
- **修复：** 至少每次启动时重新验证 `Transaction.currentEntitlements`，而非信任本地标记。

---

### H4. 全局缺少 Accessibility 标签

- **文件：** 所有 View 文件
- **典型示例：**
  - `ContentView.swift:64` — "+" 按钮无标签
  - `HomeView.swift:60-68` — 工具栏按钮无标签
  - `HomeView.swift:202-216` — "记录数据" 按钮无标签
  - `EntryDetailView.swift:99` — 菜单按钮无标签
  - `LogEntryView.swift:179-189` — 删除照片按钮无标签
  - `CameraPicker.swift` — 整个视图无无障碍支持
  - `OnboardingView.swift:23-29` — 进度指示器无信息
- **问题：** Apple 审核指南 4.1 要求所有交互元素有无障碍标签。VoiceOver 用户无法理解这些控件。
- **修复：** 为每个交互元素添加 `.accessibilityLabel()`。

---

### H5. PaywallView 缺少服务条款链接

- **文件：** `PaywallView.swift`
- **问题：** 购买界面有"恢复购买"按钮（好的），但缺少"服务条款"和"隐私政策"链接。Apple 审核指南 3.1.1 要求这两个链接在购买按钮附近可见。
- **修复：** 在购买按钮下方添加 `Link("Privacy Policy", ...)` 和 `Link("Terms of Service", ...)`。

---

### H6. 相机权限未预检查，拒绝后无降级体验

- **文件：** `CameraPicker.swift:26-37`
- **问题：** `isSourceTypeAvailable(.camera)` 返回 `true` 不代表用户已授权。若用户拒绝了相机权限，`UIImagePickerController` 会显示空白或系统弹窗。缺少 `AVCaptureDevice.authorizationStatus(for: .video)` 预检查。
- **修复：** 展示前检查授权状态，拒绝时引导用户前往设置。

---

### H7. 敏感健康数据未设置文件保护级别

- **文件：** 所有三个 Store 的 `performSave()` 方法
- **问题：** 身体数据、体重、体脂率、照片是敏感健康信息。写入时未设置 `FileProtectionType.complete`，设备锁定但连接电脑时数据可被访问。
- **修复：** `try data.write(to: Self.storeURL, options: [.atomic, .completeFileProtection])`

---

### H8. 本地化键不匹配：英文和中文 CSV 部分使用不同的键

- **文件：** `en.lproj/Localizable.strings:296-299` vs `zh-Hans.lproj/Localizable.strings:293-300`
- **问题：** CSV 导入错误部分两个语言文件使用了不同的字符串作为键。一方的键在另一方中不存在，导致显示未翻译的回退文本。
- **修复：** 统一使用相同的键，在两个文件中提供对应翻译。

---

### H9. zh-Hans 本地化文件存在重复键

- **文件：** `zh-Hans.lproj/Localizable.strings:293,299`
- **问题：** `"第 %d 行：无法解析日期: %@"` 出现两次。`.strings` 解析器使用最后一次出现，但这说明文件维护有误。
- **修复：** 删除重复条目。

---

### H10. Privacy Manifest 声明了从未使用的 UserDefaults API

- **文件：** 两份 `PrivacyInfo.xcprivacy`
- **问题：** App 不使用 `UserDefaults`/`@AppStorage`/`@SceneStorage`，所有持久化通过 JSON 文件。声明不使用的 API 可能引起审核关注。
- **修复：** 移除 `NSPrivacyAccessedAPICategoryUserDefaults` 条目。

---

### H11. Info.plist 缺少 `ITSAppUsesNonExemptEncryption`

- **文件：** `Info.plist`
- **问题：** 缺少此键，每次上传 App Store Connect 都会弹出加密合规问卷，延误审核。
- **修复：** 添加 `<key>ITSAppUsesNonExemptEncryption</key><false/>`

---

### H12. 存在两份 PrivacyInfo.xcprivacy，只有一份参与构建

- **文件：** `PrivacyInfo.xcprivacy`（根目录）和 `FormLog/PrivacyInfo.xcprivacy`
- **问题：** `project.yml` 排除了 `FormLog` 目录。`FormLog/PrivacyInfo.xcprivacy` 不参与构建，但内容与根目录版本有差异，造成维护混乱。
- **修复：** 删除 `FormLog/PrivacyInfo.xcprivacy`。

---

### H13. ShareCardView 保存照片未处理相册权限

- **文件：** `ShareCardView.swift`
- **问题：** 保存分享卡片到相册时，未检查 `PHPhotoLibrary.authorizationStatus`，若用户未授权会静默失败。
- **修复：** 保存前检查权限并引导授权。

---

### H14. SettingsView 文件导入缺少安全作用域 URL 访问

- **文件：** `SettingsView.swift`（CSV 导入逻辑）
- **问题：** 从文件选择器获取的 URL 未调用 `startAccessingSecurityScopedResource()`，在沙盒环境中可能无法读取外部文件。
- **修复：** 在读取前调用 `url.startAccessingSecurityScopedResource()`，完成后调用 `stopAccessingSecurityScopedResource()`。

---

### H15. 备份恢复缺少版本迁移

- **文件：** `SettingsView.swift`（备份恢复逻辑）
- **问题：** 从旧版 App 导出的备份文件缺少新字段时，恢复会静默失败。
- **修复：** 在恢复逻辑中添加版本检测和迁移。

---

### H16. `PurchaseManager.init` 中 `Task` 在单例完全构造前启动

- **文件：** `PurchaseManager.swift:22-27`
- **问题：** `init` 中启动的 `Task` 引用 `AppState.shared` 并捕获 `self`。虽然单例场景下不会泄漏，但若 `loadProducts` 失败，没有重试机制，用户看不到任何错误提示。
- **修复：** 将加载逻辑移到显式的 `start()` 方法中，并添加失败重试。

---

### H17. `"照片存储"` 键在英文本地化中缺失

- **文件：** `zh-Hans.lproj/Localizable.strings:297`
- **问题：** 中文有此键，英文无对应，英语用户会看到中文 "照片存储"。
- **修复：** 在 `en.lproj/Localizable.strings` 中添加 `"照片存储" = "Photo Storage";`

---

### H18. 英文 CSV 导入错误键在中文中缺失

- **文件：** `en.lproj/Localizable.strings:299`
- **问题：** `"Import failed: File encoding not supported..."` 在中文文件中无对应，中文用户会看到英文文本。
- **修复：** 在 `zh-Hans.lproj/Localizable.strings` 中添加翻译。

---

## 三、MEDIUM — 功能 / UX 缺陷（52 项）

### M1. `@StateObject` 搭配单例使用语义错误

- **文件：** `FormLogApp.swift:8,11`
- **问题：** `@StateObject` 设计用于管理对象生命周期，与 `.shared` 单例搭配时语义冲突。单例在 `@StateObject` 初始化前已存在，`@StateObject` 可能在场景重连时重建 wrapper 但底层单例保持不变。
- **修复：** 改用 `@ObservedObject` 或放弃单例模式。

---

### M2. `FormLogApp` 中环境注入重复

- **文件：** `FormLogApp.swift:15-29`
- **问题：** 四个 `environmentObject` 和 `preferredColorScheme` 在 `if/else` 两个分支中重复。如果新增环境对象只加了一边，运行时崩溃。
- **修复：** 用 `Group` 包裹后统一注入。

---

### M3. 视图根切换导致状态丢失和动画断裂

- **文件：** `FormLogApp.swift:15-29`
- **问题：** 根据 `hasCompletedOnboarding` 切换 `WindowGroup` 的根视图，整个视图层次结构被销毁重建。任何导航状态、弹窗、动画都会丢失。
- **修复：** 使用单一根视图，通过 `.fullScreenCover` 或 `ZStack` 展示引导页。

---

### M4. `primaryMetric` 回退使用无序字典

- **文件：** `BodyEntry.swift:71-74`
- **问题：** `metrics` 是 `[String: Double]`，`metrics.first` 返回任意键值对。如果记录只有非优先指标，显示的"主要指标"不可预测。
- **修复：** 按 `BodyMetricType.allCases` 顺序遍历，返回第一个匹配。

---

### M5. 体重/肌肉量单位始终显示 "kg"

- **文件：** `BodyMetricType.swift:45`
- **问题：** `unit` 属性返回静态字符串 "kg"。当用户设置为 lb 时，显示 "kg" 但值可能是 lb。
- **修复：** 让单位显示依赖用户的 `WeightUnit` 设置。

---

### M6. "维持" 目标进度为二值（0% 或 100%）

- **文件：** `GoalModel.swift:78-80`
- **问题：** 进度从 0% 跳到 100%，没有渐进反馈。距离目标 0.6kg 的用户看到 0%。
- **修复：** 返回连续值如 `max(0, 1 - diff / someMaxDeviation)`。

---

### M7. CSV 导入日期解析歧义（MM/dd vs dd/MM）

- **文件：** `BodyEntryStore.swift:38-40`
- **问题：** 两种格式同时尝试。"03/04/2024" 会被 MM/dd 格式化器先匹配为 3 月 4 日，而欧洲用户期望 4 月 3 日。无 locale 检测。
- **修复：** 检测用户 locale 仅使用对应格式，或要求 ISO 8601（yyyy-MM-dd）。

---

### M8. CSV 导出 DateFormatter 未设置 locale

- **文件：** `BodyEntryStore.swift:25-29`
- **问题：** 未设置 `locale = Locale(identifier: "en_US_POSIX")`，某些地区日历可能产生异常字符。
- **修复：** 添加 POSIX locale。

---

### M9. `checkAndMarkAchieved` 触发多次独立保存和通知

- **文件：** `GoalStore.swift:66-73`
- **问题：** 每个达成目标触发一次 `save()` 和一次通知。3 个目标同时达成 = 3 次文件写入 + 3 条通知。
- **修复：** 批量更新，保存一次，发送一条汇总通知。

---

### M10. `PhotoManager` 标记 `@unchecked Sendable` 但无同步机制

- **文件：** `PhotoManager.swift:11`
- **问题：** `ensureDirectoryExists()` 的 check-then-create 是经典的 TOCTOU 竞态条件。
- **修复：** 使用串行 `DispatchQueue` 或 `NSLock`。

---

### M11. 枚举 Category 使用中文 rawValue 作为本地化键

- **文件：** `Achievement.swift:82-89`、`BodyMetricType.swift:90-97`
- **问题：** `rawValue` 是中文（"坚持记录"），用作 `NSLocalizedString` 的键。空格或字符变化即破坏查找。对翻译者不友好。
- **修复：** 使用英文 rawValue，单独映射本地化。

---

### M12. `onChange(of:)` 单参数闭包在 iOS 17 已弃用

- **文件：** `HomeView.swift:83`、`LogEntryView.swift:220`、`PaywallView.swift:151` 等
- **问题：** 使用已弃用的 API 可能在审核时被标记。
- **修复：** 使用双参数版本 `.onChange(of:) { oldValue, newValue in ... }`

---

### M13. 无键盘收起机制

- **文件：** `LogEntryView.swift`、`OnboardingView.swift`
- **问题：** `.decimalPad` 键盘无"返回"键。没有 `.scrollDismissesKeyboard` 或点击收起手势。键盘遮挡"保存"按钮。
- **修复：** 添加 `.scrollDismissesKeyboard(.interactively)`

---

### M14. 超范围输入无视觉反馈

- **文件：** `LogEntryView.swift:266-268`
- **问题：** 超出有效范围的值（如体重 500kg）被静默忽略。用户输入后点保存，该指标直接没保存，无任何提示。
- **修复：** 显示具体的验证错误信息。

---

### M15. TextField 允许无效数字输入

- **文件：** `LogEntryView.swift:147-154`
- **问题：** `.decimalPad` 允许多个小数点（"72.5.3"），粘贴非数字文本也会被静默丢弃。
- **修复：** 在 binding 的 `set` 闭包中过滤非法字符并限制小数点数量。

---

### M16. HomeView 中 photoCount 与 Store 重复计算

- **文件：** `HomeView.swift:82-85`
- **问题：** `BodyEntryStore` 已有 `photoCount` 计算属性，HomeView 又维护了自己的 `@State` 版本，可能不同步。
- **修复：** 直接使用 `entryStore.photoCount`。

---

### M17. 硬编码 100pt 底部间距

- **文件：** `HomeView.swift:43`
- **问题：** `.padding(.bottom, 100)` 是魔法数字，在不同设备（SE、X+、iPad）上可能过多或不足。
- **修复：** 使用 `.safeAreaInset` 或依赖 TabBar 自带的安全区域。

---

### M18. Emoji 嵌入本地化键中

- **文件：** `HomeView.swift:95,142,144,156`、`OnboardingView.swift:94`
- **问题：** `"🔥 已连续记录%d天"` 包含 emoji。如果英文文件没有完全匹配的含 emoji 键，会显示中文回退。
- **修复：** 将 emoji 分离到本地化字符串外部。

---

### M19. EntryDetailView 指标按 rawValue 字母排序

- **文件：** `EntryDetailView.swift:127`
- **问题：** `sorted { $0.rawValue < $1.rawValue }` 导致体重（最重要的指标）排在最后。
- **修复：** 使用 `BodyMetricType.allCases` 顺序。

---

### M20. `UIGraphicsBeginImageContextWithOptions` 不支持广色域

- **文件：** `CameraPicker.swift:80-84`
- **问题：** 旧 API 不支持 P3 广色域，iPhone 15+ 拍摄的照片颜色可能被裁剪。
- **修复：** 改用 `UIGraphicsImageRenderer`。

---

### M21. 相机不可用时静默回退到相册

- **文件：** `CameraPicker.swift:30-33`
- **问题：** 用户点击"拍照"但打开了相册，无任何解释。
- **修复：** 弹出提示告知用户。

---

### M22. OnboardingView 无返回按钮

- **文件：** `OnboardingView.swift`
- **问题：** 用户无法回到上一步修改设置。Apple HIG 建议引导流程可导航。
- **修复：** 为 step > 0 添加返回按钮。

---

### M23. 身高输入无实时验证反馈

- **文件：** `OnboardingView.swift:155-163`
- **问题：** 用户输入 0 或 500 的值，保存时静默忽略。
- **修复：** 显示内联验证提示。

---

### M24. 通知名使用原始字符串

- **文件：** `ContentView.swift:77`
- **问题：** `.init("SwitchToHomeTab")` 易拼写错误导致静默失败。
- **修复：** 定义为 `Notification.Name` 的类型常量。

---

### M25. `greeting` 每次渲染都创建新 Date()

- **文件：** `HomeView.swift:430-438`
- **问题：** 计算属性在动画期间可能被频繁调用，理论上问候语可能在整点时突然变化。
- **修复：** 缓存在 `@State` 中，`.onAppear` 时更新。

---

### M26. 静态 DateFormatter 不随 locale 变化更新

- **文件：** `HomeView.swift:441-451`、`EntryDetailView.swift:174-178`
- **问题：** `static let` 创建的 DateFormatter 不会响应用户语言切换。
- **修复：** 监听 `NSLocale.currentLocaleDidChangeNotification` 或使用非静态实例。

---

### M27. TrendView 变化值为 nil 时图标颜色错误

- **文件：** `TrendView.swift`
- **问题：** 当变化值为 nil 时，图标可能显示错误的颜色状态。
- **修复：** 对 nil 情况设置中性颜色。

---

### M28. TrendView 使用 `Int.max` 加载所有条目的性能问题

- **文件：** `TrendView.swift`
- **问题：** 加载全部条目时使用 `Int.max` 作为限制，大数据集下可能导致内存和性能问题。
- **修复：** 使用合理的分页或限制。

---

### M29. TrendView `insights` 计算属性未缓存

- **文件：** `TrendView.swift`
- **问题：** 复杂的计算属性在每次视图渲染时重新计算，浪费 CPU。
- **修复：** 缓存到 `@State` 并在数据变化时更新。

---

### M30. Chart ForEach 中重复日期可能导致崩溃

- **文件：** `TrendView.swift`
- **问题：** 如果同一日期有多条记录，`ForEach` 使用日期作为 ID 会导致运行时冲突。
- **修复：** 使用唯一 ID 或合并同日数据。

---

### M31. Catmull-Rom 插值可能导致图表曲线超出实际值

- **文件：** `TrendView.swift`
- **问题：** Catmull-Rom 样条插值会在数据点之间产生超出实际值范围的"过冲"，可能误导用户。
- **修复：** 使用线性插值或限制插值范围。

---

### M32. ShareCardView 使用 `UIHostingController` 渲染图片

- **文件：** `ShareCardView.swift`
- **问题：** `UIHostingController` 用于离屏渲染不够稳定，应使用 iOS 16+ 的 `ImageRenderer`。
- **修复：** 改用 `ImageRenderer(content: ...)`。

---

### M33. PhotoCompareView 照片在主线程加载

- **文件：** `PhotoCompareView.swift`
- **问题：** 大尺寸照片在主线程加载，可能导致滚动卡顿。
- **修复：** 使用异步加载。

---

### M34. 指标默认值为 0 导致误导

- **文件：** 多处
- **问题：** 某些指标输入框默认显示 0，可能被误解为有效值。
- **修复：** 使用空字符串或 placeholder。

---

### M35. PhotoCompareView Before/After 顺序不正确

- **文件：** `PhotoCompareView.swift`
- **问题：** 对比视图中的"前/后"标签与实际时间顺序不符。
- **修复：** 确保较旧的照片标注为"Before"，较新的为"After"。

---

### M36. 变化值显示混用 Text 格式化

- **文件：** `TrendView.swift`
- **问题：** 正负值使用不同颜色的 `Text` 拼接，格式不一致。
- **修复：** 统一使用 `AttributedString` 或一致的格式化方式。

---

### M37. GoalStore `load()` 损坏时无备份

- **文件：** `GoalStore.swift:91-98`
- **问题：** 与 `BodyEntryStore` 不同，`GoalStore` 在加载失败时不创建损坏文件的备份，目标数据永久丢失无恢复路径。
- **修复：** 添加备份逻辑，与 `BodyEntryStore` 保持一致。

---

### M38. NotificationManager 是 ObservableObject 但无 @Published 属性

- **文件：** `NotificationManager.swift`
- **问题：** `ObservableObject` 一致性是死代码。且未标记 `@MainActor`，从 `@MainActor` 上下文调用时跨隔离边界。
- **修复：** 移除 `ObservableObject` 或添加 `@MainActor`。

---

### M39. PurchaseManager `@unknown default` 静默丢弃新购买状态

- **文件：** `PurchaseManager.swift:86-87`
- **问题：** Apple 若添加新的 `Product.PurchaseResult` case，购买静默失败，用户无反馈。
- **修复：** 记录日志并设置 `purchaseError`。

---

### M40. `restorePurchases` 复用 `isPurchasing` 标记

- **文件：** `PurchaseManager.swift:98`
- **问题：** 恢复和购买共用同一状态标记，可能互相阻塞。
- **修复：** 添加独立的 `isRestoring` 标记。

---

### M41. 备份文件路径有双扩展名

- **文件：** `BodyEntryStore.swift:444`
- **问题：** `body_entries.backup.json` 的扩展名是 `json`，但文件名包含 `.backup`，可能影响文件类型检测。且每次加载失败都覆盖上次备份。
- **修复：** 使用时间戳备份名或检查已有备份。

---

### M42. `latestValue` 重复调用 `value(for:)`

- **文件：** `BodyEntryStore.swift:139`
- **问题：** 对同一条目调用两次字典查找。
- **修复：** 使用 `compactMap { $0.value(for: type) }.first`。

---

### M43. `change30Days` 与 `totalChange` 逻辑不一致

- **文件：** `BodyEntryStore.swift:158-166`
- **问题：** `totalChange` 在只有一条记录时返回 nil，但 `change30Days` 可能在同一条记录下返回 0。
- **修复：** 添加相同的身份检查。

---

### M44. `calculateTotalStorage` 使用低效 API

- **文件：** `PhotoManager.swift:74-88`
- **问题：** 请求了 `.fileSizeKey` 资源值但忽略它，又调用 `attributesOfItem` 做额外系统调用。
- **修复：** 使用已请求的 `resourceValues`。

---

### M45. `batch-unlocked` 成就只显示第一个

- **文件：** `AppState.swift:226-229`
- **问题：** 同时解锁多个成就时只显示第一个通知，其余静默保存。
- **修复：** 使用通知队列依次显示，或显示汇总通知。

---

### M46. GoalsView 免费用户提示在空状态下显示死代码

- **文件：** `GoalsView.swift`
- **问题：** 免费用户的限制提示在空状态下的逻辑分支实际不可达。
- **修复：** 清理或调整显示逻辑。

---

### M47. 购买按钮禁用时无加载状态说明

- **文件：** `PaywallView.swift`
- **问题：** 产品加载中时按钮被禁用但无文字说明为什么不能点击。
- **修复：** 添加加载指示器或说明文字。

---

### M48. 分享卡片可能暴露健康数据

- **文件：** `ShareCardView.swift`
- **问题：** 分享卡片包含体重、体脂等敏感健康数据，用户可能在不知情的情况下分享。
- **修复：** 添加数据选择或确认步骤。

---

### M49. Info.plist 有过时的 `UIUserNotificationSettings` 键

- **文件：** `Info.plist:45-46`
- **问题：** iOS 8-9 时代的键，已被 `UNUserNotificationCenter` 取代，无效果。
- **修复：** 删除。

---

### M50. Info.plist 有空的 `UIBackgroundModes` 数组

- **文件：** `Info.plist:47-48`
- **问题：** 不使用后台模式，声明空数组不必要。
- **修复：** 删除。

---

### M51. iPad 方向配置与 iPhone-only 目标不一致

- **文件：** `Info.plist:32-38` + `project.yml:8`
- **问题：** `deviceFamily: [iphone]` 但 Info.plist 定义了 iPad 方向。
- **修复：** 删除 iPad 方向或在 project.yml 添加 iPad 支持。

---

### M52. AccentColor 缺少深色模式变体

- **文件：** `Assets.xcassets/AccentColor.colorset/Contents.json`
- **问题：** 只定义了单一颜色，深色模式下绿色可能与深色背景对比不足。
- **修复：** 添加 `luminosity: dark` 的明亮变体。

---

## 四、LOW — 代码质量 / 打磨（39 项）

| # | 文件 | 问题 |
|---|------|------|
| L1 | `BodyEntry.swift:79-85` | 自定义 `==` 冗余，编译器可自动合成 |
| L2 | `Achievement.swift:94-104` | `id` 和 `type` 冗余存储 |
| L3 | `AppState.swift:65-70,194-207` | 重量转换因子 `2.20462` 出现 4 次 |
| L4 | `GoalModel.swift:56-62` | `tolerance` 的 switch 三个分支都返回 `0.5` |
| L5 | `GoalModel.swift:66` | `startValue == targetValue` 的 guard 用户体验不佳 |
| L6 | `BodyMetricType.swift` | 缺少常见追踪指标（水摄入、卡路里等） |
| L7 | `Achievement.swift` | 照片成就缺少 50/100 里程碑 |
| L8 | `AppState.swift:47-59` | Gender 仅有 male/female/notSet |
| L9 | 三处 `save()` | 同步且频繁调用，无防抖 |
| L10 | `BodyEntryStore.swift:443-447` | 备份文件创建后永不清理或读取 |
| L11 | `BodyEntryStore.swift:441` | 加载失败静默设置 `entries = []`，不通知用户 |
| L12 | `AppState.swift:74` | `AppTheme` 缺少 `CaseIterable` |
| L13 | `PurchaseManager.swift:146-152` | `formattedPrice` 最后两个分支文本相同 |
| L14 | `NotificationManager.swift` | `sendGoalAchievedNotification` 未检查权限 |
| L15 | `AchievementManager.swift` | 无发布解锁事件的机制 |
| L16 | `BodyEntryStore.swift:248` | CSV 导入使用 `.newlines` 分割可能误切字段 |
| L17 | `BodyEntryStore.swift:139` | `latestValue` 无缓存 |
| L18 | 所有 Store | `JSONEncoder`/`JSONDecoder` 使用默认日期策略（非可读） |
| L19 | `GoalStore.swift` | 目标未排序，显示顺序依赖插入顺序 |
| L20 | 多处 View | 缺少 `#Preview` |
| L21 | 多处 View | `.cornerRadius()` 软弃用，推荐 `.clipShape(RoundedRectangle(...))` |
| L22 | `HomeView.swift:480-560` | `EntryRowView` 应独立文件 |
| L23 | `SettingsView.swift:601-670` | `MetricsPickerView` 和 `ShareSheet` 应独立文件 |
| L24 | `LogEntryView.swift:165-234` | 照片部分嵌套过深 |
| L25 | `CameraPicker.swift:77-85` | `fixOrientation` 全图重绘，高分辨率照片内存峰值高 |
| L26 | `OnboardingView.swift:135-209` | `profileStep` 无 ScrollView，小屏设备可能溢出 |
| L27 | `HomeView.swift:131,430` | `greeting` 和 `greetingSuffix` 重复逻辑 |
| L28 | `ContentView.swift:34-41` | Trend/Goals Tab 图标无 filled 变体 |
| L29 | `SettingsView.swift:672-677` | `#Preview` 缺少 `GoalStore` 注入，预览会崩溃 |
| L30 | `FormLogApp.swift:33-39` | 主题切换无过渡动画 |
| L31 | `en.lproj/Localizable.strings:100` | `"次"` 翻译为空字符串 |
| L32 | `FormLogTests.swift` | 5+ 主要组件无测试覆盖 |
| L33 | `FormLogTests.swift:122,130,208` | 测试绕过公开 API 直接修改内部状态 |
| L34 | `project.yml:44` | `DEVELOPMENT_TEAM` 为空 |
| L35 | `project.yml:45` | `ENABLE_BITCODE: NO` 在 Xcode 16 中不必要 |
| L36 | `PrivacyInfo.xcprivacy:13-14` | XML 注释在 array 元素内部 |
| L37 | `project.yml:41` | `SWIFT_VERSION: 5.0` 可更新到 5.9+ |
| L38 | `GoalStore.swift:66-73` | 遍历时修改集合的潜在风险 |
| L39 | `HomeView.swift:43` | `EntryRowView` 内的数据格式化可提取为公共工具 |

---

## 五、上架前必须修复的 TOP 10

按优先级排列，这 10 项最可能导致审核被拒或严重影响用户体验：

| 优先级 | 编号 | 问题 | 修复难度 |
|--------|------|------|----------|
| 1 | C1 | 非原子写入导致数据丢失 | 1 行代码 |
| 2 | H1 | 退款后 Pro 状态不撤销 | 中等 |
| 3 | H4 | 全局缺少无障碍标签 | 大量但机械 |
| 4 | H5 | Paywall 缺少服务条款链接 | 简单 |
| 5 | H11 | 缺少加密合规声明 | 1 行 Info.plist |
| 6 | H8 | 本地化键不匹配（中英文） | 中等 |
| 7 | C2 | 备份恢复静默失败 | 中等 |
| 8 | C3 | 无 Schema 迁移策略 | 中等 |
| 9 | M13 | 无键盘收起机制 | 简单 |
| 10 | H12 | 两份 PrivacyInfo.xcprivacy | 删除一份 |

---

## 六、文件统计

| 文件 | CRITICAL | HIGH | MEDIUM | LOW | 总计 |
|------|----------|------|--------|-----|------|
| AppState.swift | 3 | 1 | 2 | 4 | 10 |
| BodyEntryStore.swift | 2 | 1 | 7 | 5 | 15 |
| GoalStore.swift | 1 | 0 | 3 | 3 | 7 |
| PurchaseManager.swift | 0 | 3 | 3 | 2 | 8 |
| PhotoManager.swift | 1 | 0 | 2 | 2 | 5 |
| NotificationManager.swift | 0 | 0 | 2 | 1 | 3 |
| AchievementManager.swift | 0 | 0 | 0 | 1 | 1 |
| BodyEntry.swift | 0 | 0 | 1 | 1 | 2 |
| BodyMetricType.swift | 0 | 0 | 1 | 1 | 2 |
| GoalModel.swift | 0 | 0 | 2 | 2 | 4 |
| Achievement.swift | 0 | 0 | 1 | 2 | 3 |
| FormLogApp.swift | 0 | 0 | 3 | 1 | 4 |
| HomeView.swift | 0 | 1 | 5 | 4 | 10 |
| LogEntryView.swift | 0 | 1 | 4 | 2 | 7 |
| EntryDetailView.swift | 1 | 1 | 2 | 1 | 5 |
| ContentView.swift | 0 | 1 | 1 | 1 | 3 |
| OnboardingView.swift | 0 | 1 | 3 | 1 | 5 |
| CameraPicker.swift | 0 | 1 | 2 | 2 | 5 |
| TrendView.swift | 0 | 0 | 6 | 0 | 6 |
| PaywallView.swift | 0 | 1 | 2 | 0 | 3 |
| SettingsView.swift | 1 | 2 | 2 | 2 | 7 |
| ShareCardView.swift | 0 | 1 | 2 | 0 | 3 |
| PhotoCompareView.swift | 0 | 0 | 4 | 0 | 4 |
| AchievementView.swift | 0 | 0 | 0 | 0 | 0 |
| GoalsView.swift | 0 | 0 | 1 | 0 | 1 |
| Info.plist | 0 | 1 | 3 | 0 | 4 |
| project.yml | 0 | 0 | 1 | 3 | 4 |
| PrivacyInfo.xcprivacy | 0 | 2 | 0 | 1 | 3 |
| Localizable.strings (×2) | 0 | 3 | 1 | 1 | 5 |
| Assets | 0 | 0 | 1 | 0 | 1 |
| FormLogTests.swift | 0 | 0 | 2 | 2 | 4 |
| L10n.swift | 0 | 0 | 0 | 0 | 0 |
| ColorExtensions.swift | 0 | 0 | 0 | 0 | 0 |
| **总计** | **9** | **18** | **52** | **39** | **118** |

---

## 七、结论

形记 App 在功能实现上已经比较完整，UI 设计清晰，但在数据持久化安全性、IAP 合规性、无障碍支持和国际化一致性方面存在明显短板。其中原子写入（C1）和退款撤销（H1）是最紧急的两个问题 — 前者修复仅需一行代码但能防止灾难性数据丢失，后者直接影响收入。无障碍标签（H4）虽然工作量大但是 App Store 审核的硬性要求。

建议按 TOP 10 优先级顺序修复后再提交审核。
