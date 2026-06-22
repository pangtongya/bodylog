# FormLog 代码全面审计报告

**审计日期**: 2026-06-23
**审计范围**: 所有 Swift 源代码文件
**严重程度**: 🔴 致命 | 🟠 严重 | 🟡 中等 | 🟢 建议

---

## 🔴 致命问题（会导致编译失败或崩溃）

### 1. Test 文件引用了不存在的 API - AppStateTests.swift

**文件**: `Tests/AppStateTests.swift`

**问题**: 测试文件调用了大量 **AppState 实例方法**，但这些方法在实际的 `AppState.swift` 中根本不存在。

| 测试调用的方法 | 实际存在？ |
|---------------|-----------|
| `appState.toggleMetric(metric)` | ❌ 不存在 |
| `appState.isEnabled(metric)` | ❌ 不存在 |
| `appState.enableAllMetrics()` | ❌ 不存在 |
| `appState.disableAllMetrics()` | ❌ 不存在 |
| `appState.hasProFeatures` | ❌ 不存在（实际是 `isPro`） |
| `appState.validateEnabledMetrics()` | ❌ 不存在 |
| `appState.validateDisabledMetrics()` | ❌ 不存在 |
| `appState.isDataConsistent()` | ❌ 不存在 |
| `appState.backup()` | ❌ 不存在 |
| `appState.restoreFromBackup(backup)` | ❌ 不存在 |
| `AppState.Backup` 结构体 | ❌ 不存在 |
| `appState.disabledMetrics` (setter) | ❌ AppState 中 disabledMetrics 是计算属性，无 setter |

**影响**: 项目无法编译，Xcode 会报告大量 "value of type 'AppState' has no member..." 错误。

---

### 2. TrendView.swift 字符串格式化错误

**文件**: `Views/TrendView.swift`, 第 133 行

```swift
// 错误代码:
(String(format: L10n.string("已连续记录d天"), streak), L10n.string("好的开始 💪"), .formlogPrimary)
```

**问题**: `d` 前缺少 `%` 符号，应该是 `已连续记录%d天`。

**影响**: 运行时 streak 数值不会正确显示，字符串格式化会失败或显示异常。

---

### 3. AppState CodableData 缺少 disabledMetrics

**文件**: `Models/AppState.swift`

**问题**: `CodableData` 结构体没有包含 `disabledMetrics` 字段，但测试期望它存在。

```swift
// 实际的 CodableData (缺少 disabledMetrics):
private struct CodableData: Codable {
    var schemaVersion: Int
    var hasCompletedOnboarding: Bool
    var userName: String
    var userHeight: Double
    var userGender: Gender
    var weightUnit: WeightUnit
    var theme: AppTheme
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var isPro: Bool
    var enabledMetrics: [BodyMetricType]
    var achievements: [Achievement]
    // 缺少: disabledMetrics
}
```

---

### 4. SettingsView.swift 类型不匹配

**文件**: `Views/SettingsView.swift`, 第 325 行

```swift
// 声明:
@State private var exportCSV: String = ""  // 存放 URL 字符串

// 使用:
.sheet(isPresented: $showExportSheet) {
    if let url = URL(string: exportCSV) {  // 把 exportCSV 当 URL 用
        ShareSheet(items: [url])
    }
}
```

**问题**: `exportCSV` 声明为 `String` 类型但实际存的是 URL 字符串，逻辑混乱但可能勉强运行。

---

## 🟠 严重问题

### 5. PurchaseManager.start() 未被调用

**文件**: `Managers/PurchaseManager.swift`

**问题**: `PurchaseManager` 有一个 `start()` 方法用于加载产品和验证购买状态，但 `FormLogApp.swift` 中创建 `PurchaseManager` 时从未调用它。

```swift
// FormLogApp.swift:
@ObservedObject private var purchaseManager = PurchaseManager.shared
// start() 从未被调用!
```

**影响**: Pro 用户状态可能无法正确恢复，购买状态可能不正确。

---

### 6. ShareCardView 保存照片失败无用户提示

**文件**: `Views/ShareCardView.swift`, 第 223 行

```swift
} else {
    print("[ShareCardView] Photo library access denied")
    // TODO: Show error alert to user  <-- TODO 未实现
}
```

**问题**: 当保存照片失败时，只打印日志，没有 UI 反馈给用户。

---

### 7. 照片文件路径遍历防护不完整

**文件**: `Managers/PhotoManager.swift`, 第 82-91 行

```swift
func loadPhoto(filename: String) -> Data? {
    // Validate filename to prevent path traversal attacks
    guard !filename.contains("/") && !filename.contains("..") else {
        print("[PhotoManager] Invalid filename rejected: \(filename)")
        return nil
    }
    let url = photosDirectory.appendingPathComponent(filename)
    // Ensure the resolved path is within photosDirectory
    guard url.path.hasPrefix(photosDirectory.path) else {
        print("[PhotoManager] Path traversal attempt detected: \(filename)")
        return nil
    }
    // ...
}
```

**问题**: 虽然有基础防护，但 `URL.fileURL(withPath:).path` 的 `hasPrefix` 检查在某些边缘情况下可能不准确。建议使用 `url.standardizedFileURL.resourceSymlinkBookmark` 或更严格的路径解析验证。

---

### 8. BackupMigrationManager 迁移方法未实现

**文件**: `Managers/BackupMigrationManager.swift`

```swift
private func migrateFromV1_0(toV1_1 json: inout [String: Any]) -> Bool {
    print("[BackupMigrationManager] Performing 1.0 -> 1.1 migration")
    // 示例注释代码，没有实际迁移逻辑
    return true
}
```

**问题**: 迁移方法是空壳，如果未来有版本变更需要迁移，现有代码不会正确处理。

---

## 🟡 中等问题

### 9. BodyEntryStore CSV 导入性能

**文件**: `Stores/BodyEntryStore.swift`, 第 295-300 行

```swift
for (index, line) in lines.dropFirst().enumerated() {
    let lineNumber = index + 2
    let cols = parseCSVLine(line)
    progressCallback?(index + 1, lines.count - 1)  // 每次循环都回调
    // ...
}
```

**问题**: 每行都调用 progressCallback，可能导致 UI 更新过于频繁。建议批量处理或使用 throttling。

---

### 10. CameraPicker 权限处理不完整

**文件**: `Views/CameraPicker.swift`, 第 79-81 行

```swift
func setCameraMode(_ useCamera: Bool) {
    // This will be called when camera permission is granted
}
```

**问题**: `setCameraMode` 方法是空实现，当用户在权限提示后授权相机，无法自动切换回相机模式。

---

### 11. GoalModel.tolerance 是硬编码的

**文件**: `Models/GoalModel.swift`, 第 56 行

```swift
private var tolerance: Double { 0.5 }  // 所有类型统一 0.5
```

**问题**: 不同的指标类型可能需要不同的容差值（如体重 0.5kg 合理，但体脂率 0.5% 可能过大或过小）。

---

### 12. EntryDetailView 删除确认对话框消息不完整

**文件**: `Views/EntryDetailView.swift`, 第 119-124 行

```swift
if hasPhoto {
    Text(L10n.string("这条记录和照片将被永久删除，无法恢复。"))
} else {
    Text(L10n.string("这条记录将被永久删除，无法恢复。"))  // 相同消息
}
```

**问题**: 两处消息相同，条件分支无意义。

---

### 13. 没有网络状态检查

**文件**: `Managers/PurchaseManager.swift`

**问题**: 购买流程没有检查网络连接状态，用户在离线状态下会看到模糊的错误提示。

---

## 🟢 建议改进

### 14. AppState weightUnit 转换公式改进

**文件**: `Models/AppState.swift`, 第 122-128 行

```swift
func convert(_ value: Double, from source: WeightUnit) -> Double {
    if source == self { return value }
    switch self {
    case .kg: return value / 2.20462
    case .lb: return value * 2.20462
    }
}
```

**问题**: 1 lb = 0.45359237 kg，代码使用 2.20462 是倒数（不够精确）。建议:
- kg to lb: `value * 2.20462` ✓ 正确
- lb to kg: `value / 2.20462` ≈ `value * 0.453592` 近似但不够精确

---

### 15. HomeView statsRow Int 溢出风险

**文件**: `Views/HomeView.swift`, 第 391-394 行

```swift
private var statsRow: some View {
    HStack(spacing: 12) {
        statCell(value: "\(entryStore.totalRecordDays)", labelKey: "记录天数")
        statCell(value: "\(entryStore.currentStreak)", labelKey: "连续天数")
        statCell(value: "\(entryStore.thisWeekCount)", labelKey: "本周记录")
    }
}
```

**建议**: 虽然不太可能溢出，但建议添加数字格式化（如 1,000 这种千位分隔符）。

---

### 16. Localizable.strings 中英文不一致

**文件**: `Resources/en.lproj/Localizable.strings`

部分 key 在中英文版本中存在但内容不完整或与中文版本不匹配。

---

### 17. TrendView Y 轴域计算可以更智能

**文件**: `Views/TrendView.swift`, 第 97-103 行

```swift
private func computeYDomain() -> ClosedRange<Double> {
    guard !cachedDisplayData.isEmpty else { return 0...100 }
    let values = cachedDisplayData.map(\.value)
    let minVal = (values.min() ?? 0) - 2
    let maxVal = (values.max() ?? 100) + 2
    return minVal...maxVal
}
```

**问题**: `±2` 的 padding 对所有指标类型都是固定的，对 BMI(10-80 范围) 可能偏小，对体脂率(1-70) 可能偏大。

---

### 18. 缺少单元测试覆盖

当前测试文件有编译错误，无法运行。此外，以下核心功能没有测试:
- `AchievementManager`
- `GoalStore.checkAndMarkAchieved`
- `BodyEntryStore.recentValues` 边界情况
- CSV 解析边界情况

---

## 📊 汇总

| 严重程度 | 数量 |
|---------|------|
| 🔴 致命 | 4 |
| 🟠 严重 | 4 |
| 🟡 中等 | 6 |
| 🟢 建议 | 5 |

---

## 🎯 优先修复建议

1. **立即修复**: AppStateTests.swift - 删除或重写所有引用不存在 API 的测试
2. **立即修复**: TrendView.swift 字符串格式化 bug
3. **立即修复**: PurchaseManager.start() 调用缺失
4. **重要**: ShareCardView 照片保存失败的用户提示
5. **重要**: 照片路径遍历防护加强

---

*报告生成完毕，共发现 19 个问题，其中 4 个致命问题需要立即修复。*
