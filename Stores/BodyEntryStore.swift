// BodyEntryStore.swift
// 身体数据记录管理

import Foundation
import SwiftUI

@MainActor
class BodyEntryStore: ObservableObject {
    @Published var entries: [BodyEntry] = []

    private static let storeURL: URL = {
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("[BodyEntryStore] Cannot access Documents directory")
        }
        return docsDir.appendingPathComponent("body_entries.json")
    }()

    // MARK: - Shared DateFormatters (cached)
    private static let dateDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yyyyMd")
        return f
    }()

    private static let csvExportFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// CSV 导入日期格式列表（按优先级尝试解析）
    private static let csvImportFormatters: [DateFormatter] = [
        { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy HH:mm"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy HH:mm"; return f }(),
        { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }(),
    ]

    /// 尝试解析日期字符串（支持多种格式）
    private static func parseCSVDate(_ string: String) -> Date? {
        for formatter in csvImportFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    init() {
        load()
    }

    // MARK: - CRUD

    @discardableResult
    func addEntry(_ entry: BodyEntry) -> BodyEntry {
        entries.insert(entry, at: 0)
        sortEntries()
        save()
        return entry
    }

    /// 批量添加记录（用于 CSV 导入，不触发单次保存）
    func addEntries(_ newEntries: [BodyEntry]) {
        entries.insert(contentsOf: newEntries, at: 0)
        sortEntries()
        save()
    }

    func updateEntry(_ entry: BodyEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        sortEntries()
        save()
    }

    func deleteEntry(id: UUID) {
        // 先找到要删除的记录，获取照片文件名
        if let entry = entries.first(where: { $0.id == id }) {
            if let filename = entry.photoFilename {
                PhotoManager.shared.deletePhoto(filename: filename)
            }
        }
        entries.removeAll { $0.id == id }
        save()
    }

    func deleteEntries(at offsets: IndexSet) {
        // 先获取要删除的记录，删除对应照片文件
        let entriesToDelete = offsets.compactMap { idx in idx < entries.count ? entries[idx] : nil }
        for entry in entriesToDelete {
            if let filename = entry.photoFilename {
                PhotoManager.shared.deletePhoto(filename: filename)
            }
        }
        entries.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Queries

    /// 照片数量
    var photoCount: Int { entries.filter { $0.hasPhoto }.count }

    /// 最新一条记录
    var latestEntry: BodyEntry? { entries.first }

    /// 按日期分组的记录（Dictionary<String, [BodyEntry]>）
    var groupedByDate: [(key: String, value: [BodyEntry])] {
        let calendar = Calendar.current
        // Group by start-of-day Date to enable fast Date-based sorting
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            calendar.startOfDay(for: entry.recordedAt)
        }
        // Sort descending by date (newest first), then format key for display
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: Self.dateDisplayFormatter.string(from: $0.key), value: $0.value) }
    }

    /// 某个指标最近 N 条记录，用于图表
    func recentValues(for type: BodyMetricType, limit: Int = 30) -> [(date: Date, value: Double)] {
        entries
            .compactMap { entry -> (Date, Double)? in
                guard let v = entry.value(for: type) else { return nil }
                return (entry.recordedAt, v)
            }
            .prefix(limit)
            .map { (date: $0.0, value: $0.1) }
            .reversed()
    }

    /// 某个指标的最新值
    func latestValue(for type: BodyMetricType) -> Double? {
        entries.first { $0.value(for: type) != nil }?.value(for: type)
    }

    /// 某个指标的最小值（历史最低）
    func minValue(for type: BodyMetricType) -> Double? {
        entries.compactMap { $0.value(for: type) }.min()
    }

    /// 某个指标的最大值（历史最高）
    func maxValue(for type: BodyMetricType) -> Double? {
        entries.compactMap { $0.value(for: type) }.max()
    }

    /// 某个指标的起始值（最早记录）
    func startValue(for type: BodyMetricType) -> Double? {
        entries.last { $0.value(for: type) != nil }?.value(for: type)
    }

    /// 变化量（最新 - 最早）— 没有数据返回 nil，有变化但值相同返回 0
    func totalChange(for type: BodyMetricType) -> Double? {
        guard let latest = latestValue(for: type),
              let start = startValue(for: type) else { return nil }
        // 如果只有一条记录（latest 和 start 来自同一条），返回 nil 表示"没有变化可比较"
        let firstEntry = entries.first { $0.value(for: type) != nil }
        let lastEntry = entries.last { $0.value(for: type) != nil }
        if let f = firstEntry, let l = lastEntry, f.id == l.id { return nil }
        return latest - start
    }

    /// 30天变化量（最新 vs 30天前最近一条）
    func change30Days(for type: BodyMetricType) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        guard let latest = latestValue(for: type) else { return nil }
        // entries是倒序（最新在前），用.last取30天前最近的一条
        let old = entries.filter { $0.recordedAt <= cutoff }
            .last { $0.value(for: type) != nil }
        guard let oldVal = old?.value(for: type) else { return nil }
        return latest - oldVal
    }

    /// 本周记录数
    var thisWeekCount: Int {
        let start = Calendar.current.startOfWeek(for: Date())
        return entries.filter { $0.recordedAt >= start }.count
    }

    /// 总记录天数
    var totalRecordDays: Int {
        let dates = Set(entries.map { Calendar.current.startOfDay(for: $0.recordedAt) })
        return dates.count
    }

    /// 连续记录天数（streak）— 缓存优化
    private var _cachedStreak: Int?
    private var _cachedStreakEntriesCount: Int = -1

    var currentStreak: Int {
        // 如果 entries 数量没变，直接返回缓存值
        if _cachedStreakEntriesCount == entries.count, let cached = _cachedStreak {
            return cached
        }
        // 重新计算
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let recordedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.recordedAt) })

        while recordedDays.contains(checkDate) {
            streak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        _cachedStreak = streak
        _cachedStreakEntriesCount = entries.count
        return streak
    }

    // MARK: - Export / Import / Backup

    /// 生成 CSV 字符串（所有已记录指标）
    func exportCSV() -> String {
        let allMetrics = BodyMetricType.allCases
        let header = ([L10n.string("日期")] + allMetrics.map { $0.displayName + "(\($0.unit))" } + [L10n.string("备注")]).joined(separator: ",")
        let rows = entries.map { entry -> String in
            let date = Self.csvExportFormatter.string(from: entry.recordedAt)
            let values = allMetrics.map { type -> String in
                if let v = entry.value(for: type) {
                    return String(format: "%.2f", v)
                }
                return ""
            }
            // 标准 CSV：如 note 含逗号、引号或换行符，用双引号包裹
            let note: String
            if let rawNote = entry.note, !rawNote.isEmpty {
                if rawNote.contains(",") || rawNote.contains("\"") || rawNote.contains("\n") {
                    let escaped = rawNote.replacingOccurrences(of: "\"", with: "\"\"")
                    note = "\"\(escaped)\""
                } else {
                    note = rawNote
                }
            } else {
                note = ""
            }
            return ([date] + values + [note]).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// 从 CSV 字符串导入数据
    /// - Returns: (成功数, 失败原因)
    func importCSV(_ csvString: String) -> (imported: Int, error: String?) {
        let lines = csvString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count >= 2 else {
            return (0, L10n.string("CSV 文件格式不正确，至少需要标题行和一行数据"))
        }
        
        // Parse header to find column indices
        let header = parseCSVLine(lines[0])
        
        // Find date column index (try common Chinese/English headers)
        let dateColIndex = header.firstIndex(where: {
            $0.contains("日期") || $0.contains("Date") || $0.contains("date")
        }) ?? 0
        
        // Build metric type mapping from header columns
        var metricMap: [Int: BodyMetricType] = [:]
        for (idx, col) in header.enumerated() {
            if idx == dateColIndex { continue }
            for type in BodyMetricType.allCases where !type.unit.isEmpty {
                if col.contains(type.displayName) || col.contains(type.rawValue) ||
                   col.contains(type.unit) {
                    metricMap[idx] = type
                    break
                }
            }
        }
        
        // Find note column
        let noteColIndex = header.firstIndex(where: {
            $0.contains("备注") || $0.contains("Note") || $0.contains("note")
        })
        
        var importedCount = 0
        var errors: [String] = []
        var parsedEntries: [BodyEntry] = []
        
        for (index, line) in lines.dropFirst().enumerated() {
            let lineNumber = index + 2 // +1 for header, +1 for 1-based indexing
            let cols = parseCSVLine(line)
            
            guard cols.count > max(dateColIndex, 1) else { continue }
            
            // Parse date (支持多种格式)
            let dateString = cols[dateColIndex].trimmingCharacters(in: .whitespaces)
            guard let date = Self.parseCSVDate(dateString) else {
                errors.append(String(format: L10n.string("第 %d 行：无法解析日期: %@"), lineNumber, dateString))
                continue
            }
            
            // Parse metrics
            var metrics: [String: Double] = [:]
            for (colIdx, type) in metricMap where colIdx < cols.count {
                let valStr = cols[colIdx].trimmingCharacters(in: .whitespaces)
                guard !valStr.isEmpty, let val = Double(valStr) else { continue }
                metrics[type.rawValue] = val
            }
            
            guard !metrics.isEmpty else { continue }
            
            // Parse note
            var note: String? = nil
            if let nIdx = noteColIndex, nIdx < cols.count {
                let noteStr = cols[nIdx].trimmingCharacters(in: .whitespaces)
                if !noteStr.isEmpty { note = noteStr }
            }
            
            // Create entry
            let entry = BodyEntry(
                recordedAt: date,
                metrics: metrics,
                note: note
            )
            importedCount += 1
            parsedEntries.append(entry)
        }
        
        // 批量添加（只保存一次）
        if !parsedEntries.isEmpty {
            addEntries(parsedEntries)
        }
        
        if importedCount > 0 {
            let errorMsg = errors.isEmpty ? nil : String(format: L10n.string("%d 行数据跳过"), errors.count)
            return (importedCount, errorMsg)
        } else {
            if !errors.isEmpty {
                // 返回所有错误信息（最多显示5条）
                let displayErrors = errors.prefix(5)
                let errorMsg = displayErrors.joined(separator: "\n")
                let fullMsg = errors.count > 5 ? errorMsg + String(format: L10n.string("\n...还有 %d 个错误"), errors.count - 5) : errorMsg
                return (0, fullMsg)
            }
            return (0, L10n.string("未找到有效数据"))
        }
    }
    
    /// 生成CSV格式示例
    static func generateCSVTemplate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        var csv = L10n.string("日期")
        for type in BodyMetricType.allCases {
            csv += ",\(type.displayName)"
        }
        csv += "," + L10n.string("备注") + "\n"
        
        // 示例数据（只添加主要指标）
        let primaryTypes = BodyMetricType.allCases.filter { $0.category == .primary }
        var exampleRow = "\(today)"
        for type in primaryTypes {
            switch type {
            case .weight: exampleRow += ",70.5"
            case .bodyFat: exampleRow += ",18.5"
            case .muscleMass: exampleRow += ",25.0"
            case .bmi: exampleRow += ",22.5"
            default: continue
            }
        }
        exampleRow += ",笔记示例\n"
        csv += exampleRow
        
        return csv
    }
    
    /// CSV 行解析（支持引号包裹字段，处理逗号转义）
    private func parseCSVLine(_ line: String) -> [String] {
        let quote: Character = "\u{0022}"
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.makeIterator()
        
        while let ch = chars.next() {
            if inQuotes {
                if ch == quote {
                    // Check for escaped quote ("")
                    if let next = chars.peek() {
                        if next == quote {
                            current.append(quote)
                            _ = chars.next() // consume second quote
                        } else {
                            inQuotes = false
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == quote {
                    inQuotes = true
                } else if ch == "," {
                    result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        // Append last field
        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    // MARK: - Persistence
    
    func save() {
        // 立即保存，不使用延迟防抖，避免 App 被杀死时数据丢失
        performSave()
    }
    
    private func performSave() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: Self.storeURL)
        } catch {
            print("[BodyEntryStore] Save error: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Self.storeURL)
            entries = try JSONDecoder().decode([BodyEntry].self, from: data)
            sortEntries()
        } catch {
            // 数据文件不存在或损坏，首次启动或数据损坏
            print("[BodyEntryStore] Load warning: \(error). Starting with empty data.")
            entries = []
            // 可选：备份损坏的文件用于恢复
            if FileManager.default.fileExists(atPath: Self.storeURL.path) {
                let backupURL = Self.storeURL.deletingPathExtension().appendingPathExtension("backup.json")
                try? FileManager.default.copyItem(at: Self.storeURL, to: backupURL)
                print("[BodyEntryStore] Backup created at: \(backupURL.path)")
            }
        }
    }

    private func sortEntries() {
        entries.sort { $0.recordedAt > $1.recordedAt }
    }
}

// MARK: - Calendar Extension
private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Character Iterator Extension
private extension IteratorProtocol {
    /// Peek at next element without consuming it
    mutating func peek() -> Element? {
        var copy = self
        return copy.next()
    }
}
