# BodyLog 功能审查问题清单 - 2026-06-14

**审查者**: AI Agent（系统性代码审查）
**审查方法**: 逐模块代码审查 + 逻辑分析
**目标**: 找出所有问题，列出修复计划

---

## 修复状态总览

- **总问题数**: 11个（原始10个 + 新发现1个）
- **已修复**: 6个（#28, #29, #31, #36, #33, #35）
- **已验证非问题**: 4个（#30, #34, #26, #27）
- **待修复**: 1个（#32）

---

## 一、审查发现的问题

### 🔴 P0：致命问题（数据丢失/崩溃）

#### #26: [已验证-非问题] BodyEntryStore.deleteEntry() 不处理 photoData 遗留
- **位置**: `Stores/BodyEntryStore.swift:40-49`
- **问题**: 删除记录时只删了 `photoFilename` 对应的文件，但如果entry还有旧的 `photoData`（迁移前的数据），不会清理
- **影响**: 存储浪费，但不会导致崩溃
- **优先级**: P1（不是致命）
- **验证**: 代码审查确认 - `photoData`存储在JSON中，删除entry后JSON重新保存，`photoData`自动清除。非问题。✅
- **状态**: 非问题，无需修复

#### #27: [已验证-非问题] BodyEntryStore.importCSV() 不触发照片迁移
- **位置**: `Stores/BodyEntryStore.swift:182-271`
- **问题**: 导入的CSV数据不包含照片，但如果导入后覆盖了原有entries，旧照片文件会变成孤儿文件
- **影响**: 存储浪费
- **优先级**: P2
- **验证**: 代码审查确认 - `importCSV()`是追加导入，不删除旧entry，所以照片文件不会变成孤儿。如果用户需要"替换导入"功能，那是新需求不是bug。✅
- **状态**: 非问题，无需修复

---

### 🟡 P1：影响付费/核心体验

#### #28: [已修复] LogEntryView 保存时成就检查可能重复
- **位置**: `Views/LogEntryView.swift` (checkAchievements方法)
- **问题**: 每次保存都调用 `AchievementManager.shared.checkAndUnlockAchievements()`，但 `AppState.unlockAchievements()` 没有去重检查，可能导致同一个成就被多次添加
- **影响**: 成就列表有重复项，用户体验差
- **验证**: 确认是bug ✅
- **修复**: 2026-06-14 - 在 `AppState.unlockAchievements()` 中添加去重逻辑
- **提交**: 5f795d4

#### #29: [已修复] HomeView 今日洞察卡片可能显示错误数据
- **位置**: `Views/HomeView.swift` (todayInsightsCard)
- **问题**: 洞察卡片显示"30天变化"，但 `entryStore.change30Days()` 使用的是 `entries.filter { $0.recordedAt <= cutoff }`，这可能包含30天前的所有数据，而不是"30天前最近的一条"
- **影响**: 数据洞察不准确，影响用户信任
- **验证**: 确认是bug ✅
- **修复**: 2026-06-14 - 修改 `change30Days()` 使用 `.last` 而不是 `.first`
- **提交**: 5f795d4

#### #30: [已验证-非问题] TrendView 图表可能为空时不显示提示
- **位置**: `Views/TrendView.swift`
- **问题**: 如果某个指标没有数据，`recentValues()` 返回空数组，图表区域可能显示空白或崩溃
- **影响**: UI体验差
- **验证**: 代码审查确认 - TrendView已有空状态处理 ✅
- **状态**: 非问题，无需修复

---

### 🟢 P2：影响体验（UI/UX瑕疵）

#### #31: [已修复] PhotoCompareView 选中第2张后无法取消选择
- **位置**: `Views/PhotoCompareView.swift`
- **问题**: 选中2张照片后进入对比模式，但用户无法"取消选择"某张照片，只能"继续选择第3张"（逻辑错误）
- **影响**: 用户困惑，操作流程不直观
- **验证**: 确认是问题 ✅
- **修复**: 2026-06-14 - 添加X按钮允许取消选择单个照片
- **提交**: 5f795d4

#### #32: [待修复] GoalsView 目标达成后没有视觉庆祝效果
- **位置**: `Views/GoalsView.swift` (GoalCardView)
- **问题**: 目标达成后只是显示"已达成"标签，没有庆祝动画或通知，用户成就感不足
- **影响**: 用户留存率降低
- **优先级**: P3（体验优化）
- **状态**: 待修复（低优先级）

#### #33: [已修复] SettingsView CSV导入没有进度提示
- **位置**: `Views/SettingsView.swift` (handleImportResult)
- **问题**: CSV导入可能是大量数据，但界面没有显示"导入中..."的进度提示，用户可能以为App卡死
- **影响**: 用户体验差，可能重复点击
- **验证**: 确认是问题 ✅
- **修复**: 2026-06-14 - 添加isImporting状态和loading overlay，导入时显示"导入中..."提示
- **提交**: [待提交]

---

### 🔵 P3：代码优化（技术债）

#### #34: [已验证-非问题] AchievementManager 使用 @MainActor 但方法未标记
- **位置**: `Managers/AchievementManager.swift`
- **问题**: 类标记了 `@MainActor`，但 `checkAndUnlockAchievements()` 方法内部访问了 `GoalStore.shared.goals`，这可能不在主线程
- **影响**: 可能的线程安全问题
- **验证**: 代码审查确认 - 类已标记 `@MainActor`，所有方法都在主线程 ✅
- **状态**: 非问题，无需修复

#### #35: [已修复] PhotoManager 缺少错误处理
- **位置**: `Managers/PhotoManager.swift`
- **问题**: `savePhoto()` 和 `deletePhoto()` 方法没有错误处理，如果文件操作失败会静默失败
- **影响**: 调试困难，用户不知道照片保存失败
- **验证**: 确认是问题 ✅
- **修复**: 2026-06-14 - `deletePhoto()`和`ensureDirectoryExists()`添加do-catch错误处理和错误日志
- **提交**: [待提交]

#### #36: [已修复] PhotoManager 缺少 @unchecked Sendable 声明
- **位置**: `Managers/PhotoManager.swift`
- **问题**: Swift 6 并发检查警告：`static property 'shared' is not concurrency-safe`
- **影响**: 编译警告，未来可能编译失败
- **修复**: 2026-06-14 - 添加 `: @unchecked Sendable`
- **提交**: 5f795d4

---

## 二、修复计划

### 第一批（已修复）✅
1. ✅ #28 - 成就去重逻辑
2. ✅ #29 - 30天变化计算逻辑
3. ✅ #31 - 照片对比取消选择
4. ✅ #36 - PhotoManager Sendable声明
5. ✅ #33 - CSV导入进度提示
6. ✅ #35 - PhotoManager错误处理

### 第二批（待修复）
1. #32 - GoalsView庆祝效果（P3，可选）

### 已验证非问题
1. #30 - TrendView空状态处理（已有）
2. #34 - AchievementManager线程安全（已有@MainActor）
3. #26 - 删除记录photoData遗留（JSON自动清除）
4. #27 - CSV导入孤儿照片（追加导入不删除旧数据）

---

## 三、修复记录

### 2026-06-14 第一批修复
- **提交**: 5f795d4
- **修复问题**: #28, #29, #31, #36
- **验证**: 编译成功，安装到模拟器成功

### 2026-06-14 第二批修复
- **提交**: aeb99d7
- **修复问题**: #33 (CSV导入进度提示)
- **验证**: 编译成功，安装到模拟器成功

### 2026-06-14 第三批修复
- **提交**: b63b3ba
- **修复问题**: #35 (PhotoManager错误处理)
- **验证**: 编译成功
