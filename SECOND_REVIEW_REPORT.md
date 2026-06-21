# FormLog 第二轮代码审查报告

> **审查日期**: 2026-06-21（第二轮）
> **审查人**: AI Agent（逐行阅读全部 27 个 Swift 文件 + 配置文件）
> **审查标准**: 以精益求精的态度，找出第一轮遗漏的问题

---

## 执行摘要

第一轮审查修复了 20 个问题，但经过第二轮逐行复查，又发现了 **15 个新问题**，其中包含 1 个 P0 性能 Bug 和多个国际化遗漏。

| 级别 | 数量 | 说明 |
|------|------|------|
| P0 致命 | 1 | TrendView insights 无限重渲染 |
| P1 严重 | 8 | 国际化遗漏、性能问题、死代码 |
| P2 中等 | 6 | 代码质量、冗余逻辑 |

---

## P0 致命问题

### #1 TrendView insights 每次访问生成新 UUID，导致无限重渲染 🔥

**位置**: `Views/TrendView.swift` 第 279-333 行

**问题**: `insights` 计算属性每次被访问时，都为每个洞察项生成新的 `UUID()`：
```swift
result.append((id: UUID(), icon: "calendar.badge.clock", text: text, ...))
```

而 `insightsCard` 中使用 `ForEach(Array(insights.enumerated()), id: \.element.id)` 以这些 UUID 作为视图标识。

SwiftUI 每次 body 求值都会访问 `insights`，生成全新的 UUID，ForEach 认为所有项目都变了，触发重新渲染 → 再次求值 body → 再次访问 insights → 又生成新 UUID → **无限循环**。

**影响**:
- 趋势页 CPU 占用异常高
- 滚动卡顿、耗电增加
- 严重时导致 App 卡死

**修复方案**: 用稳定的 ID（如 Int 索引或字符串）替代 UUID：
```swift
result.append((id: "insight_0", icon: ..., text: ..., ...))
```

---

## P1 严重问题

### #2 大量三目运算和 String 变量未本地化

**位置**: 多个文件

SwiftUI 的 `Text("字面量")` 自动本地化，但 `Text(条件 ? "a" : "b")` 和 `Text(stringVariable)` **不会**。以下是遗漏的完整清单：

| 文件 | 行号 | 代码 | 问题 |
|------|------|------|------|
| HomeView | 204 | `Text(entryStore.entries.isEmpty ? "记录第一条数据" : "记录今天数据")` | 三目运算→String，不本地化 |
| HomeView | 365-367 | `statCell(value:label:)` label 参数 | String 参数→Text(label)，不本地化 |
| LogEntryView | 61 | `.navigationTitle(isEditing ? "编辑记录" : "记录数据")` | 三目运算→String |
| LogEntryView | 76 | `Button(isEditing ? "保存" : "记录")` | 三目运算→String |
| TrendView | 157-191 | `statCell(title: "当前值", ...)` 等 | String 参数→Text(title) |
| TrendView | 192 | `unit: "次"` | String 参数→Text(unit) |

### #3 HomeView greetingSuffix 使用中文逗号

**位置**: `Views/HomeView.swift` 第 126-128 行、第 429 行

```swift
let name = appState.userName.isEmpty ? "" : "，\(appState.userName)"
```

中文逗号 `，` 硬编码。英文环境应使用 `, `（英文逗号+空格）。

### #4 CSV 导入错误消息未本地化

**位置**: `Stores/BodyEntryStore.swift` 第 197、242、276、278 行

```swift
return (0, "CSV 文件格式不正确，至少需要标题行和一行数据")
errors.append("无法解析日期: \(dateString)")
"\(errors.count) 行数据跳过"
"未找到有效数据"
```

4 条 CSV 导入错误消息硬编码中文，英文用户会看到中文错误。

### #5 Info.plist 权限描述只有中文

**位置**: `Info.plist` 第 39-43 行

```xml
<key>NSCameraUsageDescription</key>
<string>用于拍摄身体对比照片，记录您的形体变化。</string>
```

相机和相册权限描述只有中文。英文用户在系统权限弹窗中会看到中文。应通过 `InfoPlist.strings` 本地化。

### #6 DateFormatter 每次访问都新建，性能问题

**位置**: 多个文件

| 文件 | 位置 | 问题 |
|------|------|------|
| BodyEntryStore | 68-69 | `groupedByDate` 每次访问新建 DateFormatter |
| HomeView | 441-443 | `relativeDate` 每次调用新建 DateFormatter |
| EntryRowView | 539-541 | `timeString` 每行记录新建 DateFormatter |
| TrendView | 间接 | 通过 groupedByDate 触发 |

DateFormatter 初始化成本很高。在列表滚动时，每行都会创建新的 formatter。

### #7 BodyEntry.photoData 死字段

**位置**: `Models/BodyEntry.swift` 第 19 行

`photoData: Data?` 字段仍在模型中，仍被 Codable 编码/解码，但已不再使用（照片改为文件存储）。它使 JSON 文件膨胀，且 `migrateLegacyPhotos()` 在每次加载时都遍历所有记录检查是否需要迁移——App 未上架，没有旧数据需要迁移。

### #8 AppState.userBirthYear 收集但从不使用

**位置**: `Models/AppState.swift` 第 17 行

`userBirthYear` 在引导页收集、持久化存储，但整个 App 中**从未被读取或使用**。没有任何计算（如年龄、BMI）依赖它。浪费用户时间收集无用数据。

---

## P2 中等问题

### #9 BodyMetricType.unitLb 死代码

**位置**: `Models/BodyMetricType.swift` 第 52-57 行

`unitLb` 计算属性定义了但从未被调用。

### #10 HomeView displayValue 死分支

**位置**: `Views/HomeView.swift` 第 451-454 行

```swift
if type == .bodyFat || type == .bmi {
    return (String(format: "%.1f", value), type.unit)
}
return (String(format: "%.1f", value), type.unit)
```

两个分支返回完全相同的值，if 判断无意义。

### #11 BodyEntryStore migrateLegacyPhotos 不必要的迁移

**位置**: `Stores/BodyEntryStore.swift` 第 353-367 行

每次 `load()` 都调用 `migrateLegacyPhotos()`，遍历所有 entries 检查是否需要迁移。App 未上架，无旧数据。

### #12 TrendView chartData limit 500 可能截断数据

**位置**: `Views/TrendView.swift` 第 36 行

```swift
let all = entryStore.recentValues(for: selectedMetric, limit: 500)
```

500 是硬编码上限。长期用户（2年+每天记录）可能有超过 500 条数据，"全部"时间范围下会截断。

### #13 TrendView displayData/chartData 每次 body 求值都重算

**位置**: `Views/TrendView.swift` 第 35-51 行

`chartData` 和 `displayData` 是计算属性，每次视图 body 求值都重新计算（filter、map、reversed）。应缓存或使用 @State。

### #14 HomeView photoCompareEntry 每次求值都 filter 全部 entries

**位置**: `Views/HomeView.swift` 第 308 行

```swift
let photoCount = entryStore.entries.filter { $0.hasPhoto }.count
```

每次 body 求值都遍历所有 entries 计算照片数量。

### #15 LogEntryView prefillIfEditing 可能被重复调用

**位置**: `Views/LogEntryView.swift` 第 95 行

`.onAppear { prefillIfEditing() }` 在视图出现时调用。如果 App 从后台恢复，onAppear 可能再次触发，重置用户已做的修改。

---

## 修复优先级

### 第一批（必须修复）
1. P0 #1: TrendView insights UUID → 改用稳定 ID
2. P1 #2: 三目运算/String 变量本地化 → L10n.string()
3. P1 #3: greetingSuffix 中文逗号 → 本地化
4. P1 #4: CSV 错误消息本地化
5. P1 #5: Info.plist 权限描述本地化
6. P1 #6: DateFormatter 缓存
7. P1 #7: 移除 photoData 死字段
8. P1 #8: 移除 userBirthYear 或实际使用它

### 第二批（代码质量）
9. P2 #9: 移除 unitLb
10. P2 #10: 移除 displayValue 死分支
11. P2 #11: 移除 migrateLegacyPhotos
12. P2 #12-15: 性能优化和边界修复
