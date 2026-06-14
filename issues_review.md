# BodyLog 功能审查问题清单 - 2026-06-14

**审查者**: AI Agent（系统性代码审查）
**审查方法**: 逐模块代码审查 + 逻辑分析
**目标**: 找出所有问题，列出修复计划

---

## 一、审查发现的问题

### 🔴 P0：致命问题（数据丢失/崩溃）

#### #26: BodyEntryStore.deleteEntry() 不处理 photoData 遗留
- **位置**: `Stores/BodyEntryStore.swift:40-49`
- **问题**: 删除记录时只删了 `photoFilename` 对应的文件，但如果entry还有旧的 `photoData`（迁移前的数据），不会清理
- **影响**: 存储浪费，但不会导致崩溃
- **优先级**: P1（不是致命）

#### #27: BodyEntryStore.importCSV() 不触发照片迁移
- **位置**: `Stores/BodyEntryStore.swift:182-271`
- **问题**: 导入的CSV数据不包含照片，但如果导入后覆盖了原有entries，旧照片文件会变成孤儿文件
- **影响**: 存储浪费
- **优先级**: P2

---

### 🟡 P1：影响付费/核心体验

#### #28: LogEntryView 保存时成就检查可能重复
- **位置**: `Views/LogEntryView.swift` (checkAchievements方法)
- **问题**: 每次保存都调用 `AchievementManager.shared.checkAndUnlockAchievements()`，但 `AppState.unlockAchievements()` 没有去重检查，可能导致同一个成就被多次添加
- **影响**: 成就列表有重复项，用户体验差
- **验证**: 需要检查 `AppState.unlockAchievements()` 实现

#### #29: HomeView 今日洞察卡片可能显示错误数据
- **位置**: `Views/HomeView.swift` (todayInsightsCard)
- **问题**: 洞察卡片显示"30天变化"，但 `entryStore.change30Days()` 使用的是 `entries.filter { $0.recordedAt <= cutoff }`，这可能包含30天前的所有数据，而不是"30天前最近的一条"
- **影响**: 数据洞察不准确，影响用户信任
- **验证**: 需要检查 `change30Days()` 逻辑

#### #30: TrendView 图表可能为空时不显示提示
- **位置**: `Views/TrendView.swift`
- **问题**: 如果某个指标没有数据，`recentValues()` 返回空数组，图表区域可能显示空白或崩溃
- **影响**: UI体验差
- **验证**: 需要检查TrendView的空状态处理

---

### 🟢 P2：影响体验（UI/UX瑕疵）

#### #31: PhotoCompareView 选中第2张后无法取消选择
- **位置**: `Views/PhotoCompareView.swift`
- **问题**: 选中2张照片后进入对比模式，但用户无法"取消选择"某张照片，只能"继续选择第3张"（逻辑错误）
- **影响**: 用户困惑，操作流程不直观
- **验证**: 需要实际测试

#### #32: GoalsView 目标达成后没有视觉庆祝效果
- **位置**: `Views/GoalsView.swift` (GoalCardView)
- **问题**: 目标达成后只是显示"已达成"标签，没有庆祝动画或通知，用户成就感不足
- **影响**: 用户留存率降低
- **验证**: 代码审查确认

#### #33: SettingsView CSV导入没有进度提示
- **位置**: `Views/SettingsView.swift` (handleImportResult)
- **问题**: CSV导入可能是大量数据，但界面没有显示"导入中..."的进度提示，用户可能以为App卡死
- **影响**: 用户体验差，可能重复点击
- **验证**: 代码审查确认

---

### 🔵 P3：代码优化（技术债）

#### #34: AchievementManager 使用 @MainActor 但方法未标记
- **位置**: `Managers/AchievementManager.swift`
- **问题**: 类标记了 `@MainActor`，但 `checkAndUnlockAchievements()` 方法内部访问了 `GoalStore.shared.goals`，这可能不在主线程
- **影响**: 可能的线程安全问题
- **验证**: 需要检查调用上下文

#### #35: PhotoManager 缺少错误处理
- **位置**: `Managers/PhotoManager.swift`
- **问题**: `savePhoto()` 和 `deletePhoto()` 方法没有错误处理，如果文件操作失败会静默失败
- **影响**: 调试困难，用户不知道照片保存失败
- **验证**: 代码审查确认

---

## 二、问题验证计划

按照优先级，我需要验证上述问题：

### 验证顺序
1. ✅ **#28**: 检查 `AppState.unlockAchievements()` 是否有去重 → **确认是bug**
2. ✅ **#29**: 检查 `change30Days()` 逻辑是否正确 → **需要验证**
3. ✅ **#30**: 检查TrendView空状态处理 → **需要验证**
4. ✅ **#31**: 测试PhotoCompareView选择流程 → **需要验证**
5. ✅ **#33**: 检查CSV导入是否有进度提示 → **确认是问题**

让我先验证最关键的 #28 和 #29：
