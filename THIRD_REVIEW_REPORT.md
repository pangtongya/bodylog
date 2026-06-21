# FormLog 第三轮全面审查报告

> **审查日期**: 2026-06-21（第三轮）
> **审查人**: AI Agent（逐行阅读全部 29 个 Swift 文件）
> **审查标准**: 精益求精，不放过任何潜在问题

---

## 执行摘要

经过全面审查，发现 **4 个 P0 致命问题**、**8 个 P1 严重问题**、**12 个 P2 中等问题**，以及 **6 个 P3 轻微问题**。

---

## P0 致命问题（必须修复）

### #1 ShareCardView 硬编码 App 名称

**位置**: `Views/ShareCardView.swift` 第 64 行、第 138 行

```swift
Text(L10n.string("FormLog 形记"))  // Line 64
Text("FormLog")  // Line 138
```

**问题**: App 名称硬编码在代码中，如果用户修改了 App 显示名称（如上架后改名），这两处不会更新。

**修复**: 使用 `Bundle.main.infoDictionary?["CFBundleDisplayName"]` 或在 InfoPlist.strings 中定义。

---

### #2 L10n.string 格式化参数类型不安全

**位置**: `Utilities/L10n.swift` 第 21-22 行

```swift
static func string(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), args)
}
```

**问题**: `CVarArg...` 不够类型安全，无法在编译期检查参数数量和类型是否匹配。

**修复**: 使用泛型变体：
```swift
static func string(_ key: String, _ args: String...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}
```

---

### #3 documentDirectory URL 缺少空值检查

**位置**:
- `Models/AppState.swift` 第 98 行
- `Stores/BodyEntryStore.swift` 第 12-14 行
- `Stores/GoalStore.swift` 第 12-14 行

```swift
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
```

**问题**: 如果 `.documentDirectory` 返回空数组，访问 `[0]` 会崩溃。

**修复**: 添加安全检查：
```swift
guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
    // 处理错误
}
```

---

### #4 CSV 导出使用硬编码中文表头

**位置**: `Stores/BodyEntryStore.swift` 第 198 行

```swift
let header = (["日期"] + allMetrics.map { ... } + ["备注"]).joined(separator: ",")
```

**问题**: CSV 导出表头硬编码为 "日期"、"备注"，英文用户导出的 CSV 也是中文表头。

**修复**: 使用本地化字符串。

---

## P1 严重问题

### #5 身高输入缺少上限校验

**位置**: `Views/OnboardingView.swift` 第 286 行

```swift
if let h = Double(heightStr), h > 0 { appState.userHeight = h }
```

**问题**: 只检查 `h > 0`，没有上限。用户可以输入 9999cm。

**修复**: 添加上限 `h > 0 && h <= 300`。

---

### #6 SettingsView 硬编码 "cm" 单位

**位置**: `Views/SettingsView.swift` 第 56 行

```swift
Text("cm").foregroundColor(.secondary)
```

**问题**: "cm" 硬编码，应使用本地化。

---

### #7 SettingsView 指标管理 "完成" 硬编码

**位置**: `Views/SettingsView.swift` 第 509 行

```swift
Button("完成") { isPresented = false }
```

**问题**: "完成" 硬编码，应使用 `L10n.string("完成")`。

---

### #8 照片同步加载可能阻塞 UI

**位置**:
- `Views/EntryDetailView.swift` 第 28 行
- `Views/PhotoCompareView.swift` 第 149 行

```swift
if let data = entry.loadedPhotoData, let image = UIImage(data: data) {
```

**问题**: `loadedPhotoData` 是同步读取文件，大照片可能造成 UI 卡顿。

**修复**: 使用 `async/await` 或 `Task` 异步加载：
```swift
@State private var loadedImage: UIImage?
@State private var isLoading = true

Task {
    if let data = entry.loadedPhotoData,
       let image = UIImage(data: data) {
        loadedImage = image
    }
    isLoading = false
}
```

---

### #9 CSV 导入每行都触发保存（性能问题）

**位置**: `Stores/BodyEntryStore.swift` 第 302 行

```swift
addEntry(entry)  // 内部调用 sortEntries() 和 save()
```

**问题**: 在循环中每次 `addEntry` 都触发保存，导入 1000 条数据会保存 1000 次。

**修复**: 在 `importCSV` 中使用批量插入：
```swift
func importCSV(_ csvString: String) {
    var newEntries: [BodyEntry] = []
    // ... 解析 ...
    for line in lines.dropFirst() {
        // 解析...
        let entry = BodyEntry(...)
        newEntries.append(entry)
    }
    // 批量添加
    entries.insert(contentsOf: newEntries, at: 0)
    sortEntries()
    save()
}
```

---

### #10 CSV 日期格式硬编码

**位置**: `Stores/BodyEntryStore.swift` 第 26 行

```swift
f.dateFormat = "yyyy-MM-dd HH:mm"
```

**问题**: 导出格式固定为 `yyyy-MM-dd HH:mm`，如果用户需要其他格式（如 `yyyy/MM/dd`）无法配置。

**修复**: 作为 P3 可选改进。

---

### #11 ShareSheet URL 创建不安全

**位置**: `Views/SettingsView.swift` 第 275 行

```swift
if let url = URL(string: exportCSV) {
```

**问题**: `exportCSV` 是文件路径字符串，`URL(string:)` 可能对特殊字符处理不当。

**修复**: 直接存储 URL 而非字符串：
```swift
@State private var exportURL: URL?
```

---

## P2 中等问题

### #12 Emoji 在部分文本中未使用 SF Symbols 替代

**位置**: 多个文件

- `Views/HomeView.swift` 第 95 行: "👋" 硬编码
- `Views/TrendView.swift` 第 307-344 行: "💪", "🎯", "😊", "🔥", "👍", "✨" 等
- `Views/GoalsView.swift` 第 117, 273 行
- `Views/PhotoCompareView.swift` 第 195, 232, 316 行
- `Views/AchievementView.swift` 第 184 行
- `Views/OnboardingView.swift` 第 94 行

**问题**: Emoji 在某些语言环境下可能显示不正确，应优先使用 SF Symbols。

**修复**: 建议将部分常用 Emoji 替换为 SF Symbols：
- "👋" → 可用 "hand.wave.fill" 但较复杂，建议保留
- "💪" → SF Symbol 不存在，保留
- "🔥" → SF Symbol 不存在，保留
- 其他意义不大的 Emoji 可移除

---

### #13 指标排序使用英文字段名

**位置**: `Views/EntryDetailView.swift` 第 127 行

```swift
.sorted { $0.rawValue < $1.rawValue }
```

**问题**: 按英文 rawValue 排序（weight, bodyFat...），不是按用户友好的顺序。

**修复**: 定义显示顺序枚举。

---

### #14 GoalModel maintain 容差固定

**位置**: `Models/GoalModel.swift` 第 70-71 行

```swift
let diff = abs(currentValue - targetValue)
return diff < 1.0 ? 1.0 : 0.0
```

**问题**: 容差固定为 1.0，但体重用 kg、围度用 cm，容差应不同。

**修复**: 根据指标类型设置不同容差。

---

### #15 每日提醒只取消待发送通知

**位置**: `Managers/NotificationManager.swift` 第 65-67 行

```swift
func cancelDailyReminder() {
    notificationCenter.removePendingNotificationRequests(withIdentifiers: ["formlog.daily_reminder"])
}
```

**问题**: 只移除待发送的通知，用户已收到的通知不会被清除。

**修复**: 也移除已发送的通知（可选，因为每日通知本应每天重发）。

---

### #16 AchievementManager 照片计数低效

**位置**: `Managers/AchievementManager.swift` 第 99, 102 行

```swift
entryStore.entries.filter { $0.hasPhoto }.count
```

**问题**: 每次计算成就进度都 filter 一遍，可以缓存。

**修复**: 在 `BodyEntryStore` 中添加 `photoCount` 计算属性并缓存。

---

### #17 CSV 导入日期格式兼容性

**位置**: `Stores/BodyEntryStore.swift` 第 273-274 行

```swift
guard let date = dateFormatter.date(from: dateString) ??
              shortDateFormatter.date(from: dateString)
```

**问题**: 只支持 `yyyy-MM-dd HH:mm` 和 `yyyy-MM-dd` 两种格式，不支持 `yyyy/MM/dd`、`MM/dd/yyyy` 等。

**修复**: 添加更多日期格式支持。

---

## P3 轻微问题

### #18 BodyEntryStore 错误处理静默失败

**位置**: `Stores/BodyEntryStore.swift` 第 377-379 行

```swift
} catch {
    entries = []
}
```

**问题**: 如果数据损坏，用户完全丢失数据，没有恢复选项。

**修复**: 尝试备份损坏文件后再清空。

---

### #19 AppState 错误处理静默失败

**位置**: `Models/AppState.swift` 第 146-148 行

```swift
} catch {
    // 首次启动，使用默认值
}
```

**问题**: 静默失败，用户不知道数据可能有问题。

---

### #20 ShareCardView 日期格式未本地化

**位置**: `Views/ShareCardView.swift` 第 229-231 行

```swift
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("yyyyMd")
    return f
}()
```

**问题**: 使用固定的日期模板 `yyyyMd`，不尊重用户区域设置。

**修复**: 已使用 `setLocalizedDateFormatFromTemplate`，应该尊重系统区域设置。

---

### #21 EntryDetailView 日期格式未本地化

**位置**: `Views/EntryDetailView.swift` 第 174-178 行

```swift
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MdHHmm")
    return f
}()
```

**问题**: 同上。

---

### #22 PhotoCompareView 日期格式未本地化

**位置**: `Views/PhotoCompareView.swift` 第 384-388 行

**问题**: 同上。

---

## 建议改进（非问题）

1. **添加单元测试覆盖率**：当前测试覆盖了基础功能，建议添加 UI 测试。
2. **添加 Instruments 检测**：用Leaks、Time Profiler 检测内存和性能。
3. **App Store 截图**：确保在不同尺寸设备上的显示效果。
4. **隐私政策 URL**：当前硬编码，可考虑在 InfoPlist 中配置。

---

## 修复优先级排序

### 第一批（必须修复，上架前）
1. P0 #3: documentDirectory URL 空值检查
2. P0 #4: CSV 导出使用本地化表头
3. P1 #5: 身高输入上限校验
4. P1 #6: "cm" 单位本地化
5. P1 #7: "完成" 按钮本地化
6. P1 #9: CSV 导入批量保存优化

### 第二批（强烈建议）
7. P0 #1: ShareCardView App 名称
8. P0 #2: L10n 格式化参数类型
9. P1 #8: 照片异步加载
10. P1 #10: CSV 日期格式说明

### 第三批（可选）
11. P2 #12: Emoji 清理
12. P2 #13: 指标排序
13. P2 #14: GoalModel 容差
14. P2 #15: 通知清理
15. P2 #16: 照片计数缓存
16. P2 #17: CSV 日期格式兼容性
