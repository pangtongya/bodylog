// BodyEntryStore.swift
// 身体数据记录管理

import Foundation
import SwiftUI
import os.log

@MainActor
class BodyEntryStore: ObservableObject {
    @Published var entries: [BodyEntry] = []

    // MARK: - Structured Logger
    private static let logger = Logger(subsystem: "com.pangtong.formlog", category: "BodyEntryStore")

    // MARK: - Backup Size Limit (10 MB)
    private static let maxBackupSizeBytes: Int = 10 * 1024 * 1024

    // MARK: - Debounce Save
    private var saveDebounceTask: Task<Void, Never>?
    private static let saveDebounceInterval: UInt64 = 100_000_000 // 100ms in nanoseconds

    // Error callbacks for UI feedback
    private var saveErrorHandler: ((String) -> Void)?
    private var loadErrorHandler: ((String) -> Void)?

    private static let storeURL: URL = {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fallbackDir = FileManager.default.temporaryDirectory
        let baseURL = docsDir ?? fallbackDir
        return baseURL.appendingPathComponent("body_entries.json")
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
        f.locale = Locale(identifier: "en_US_POSIX")
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

    // MARK: - Error Handling Setup

    /// 设置保存错误处理器
    func setSaveErrorHandler(_ handler: @escaping (String) -> Void) {
        saveErrorHandler = handler
    }

    /// 设置加载错误处理器
    func setLoadErrorHandler(_ handler: @escaping (String) -> Void) {
        loadErrorHandler = handler
    }

    // MARK: - Streak Cache Invalidation

    /// Invalidate the streak cache so it is recalculated on next access.
    private func invalidateStreakCache() {
        _cachedStreak = nil
        _cachedStreakDatesHash = 0
    }

    // MARK: - CRUD

    @discardableResult
    func addEntry(_ entry: BodyEntry) -> BodyEntry {
        entries.insert(entry, at: 0)
        sortEntries()
        invalidateStreakCache()
        save()
        return entry
    }

    /// 批量添加记录（用于 CSV 导入，不触发单次保存）
    func addEntries(_ newEntries: [BodyEntry]) {
        entries.insert(contentsOf: newEntries, at: 0)
        sortEntries()
        invalidateStreakCache()
        save()
    }

    func updateEntry(_ entry: BodyEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        sortEntries()
        invalidateStreakCache()
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
        invalidateStreakCache()
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
        invalidateStreakCache()
        save()
    }

    // MARK: - Queries

    /// 照片数量
    var photoCount: Int { entries.filter { $0.hasPhoto }.count }

    /// 是否使用过照片对比功能
    var hasUsedPhotoCompare: Bool {
        UserDefaults.standard.bool(forKey: "hasUsedPhotoCompare")
    }

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
    private var _cachedStreakDatesHash: Int = 0

    private func computeStreakDatesHash() -> Int {
        let dates = Set(entries.map { Calendar.current.startOfDay(for: $0.recordedAt) })
        return dates.hashValue
    }

    var currentStreak: Int {
        // If entries' date set hasn't changed, return cached value
        let currentHash = computeStreakDatesHash()
        if _cachedStreakDatesHash == currentHash, let cached = _cachedStreak {
            return cached
        }
        // Recalculate
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let recordedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.recordedAt) })

        while recordedDays.contains(checkDate) {
            streak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        _cachedStreak = streak
        _cachedStreakDatesHash = currentHash
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
    /// - Parameter progressCallback: 进度回调函数 (当前进度, 总进度)
    /// - Returns: (成功数, 失败原因)
    func importCSV(_ csvString: String, progressCallback: ((Int, Int) -> Void)? = nil) -> (imported: Int, error: String?) {
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

        // Validation: date column must be present in header
        guard dateColIndex < header.count else {
            Self.logger.error("CSV import failed: date column index \(dateColIndex) is out of bounds for header with \(header.count) columns")
            return (0, L10n.string("CSV 文件缺少日期列"))
        }

        // Validation: missing required fields check — date column must exist
        if header.isEmpty || dateColIndex >= header.count {
            Self.logger.error("CSV import failed: header is empty or date column missing")
            return (0, L10n.string("CSV 文件缺少日期列"))
        }

        var importedCount = 0
        var errors: [String] = []
        var parsedEntries: [BodyEntry] = []
        var duplicateDates: Set<Date> = []

        // Build a set of (date + metric) keys already present in the store to detect duplicates
        var existingKeys: Set<String> = []
        for entry in entries {
            let day = Calendar.current.startOfDay(for: entry.recordedAt)
            for type in BodyMetricType.allCases {
                if entry.value(for: type) != nil {
                    existingKeys.insert("\(day.timeIntervalSince1970)_\(type.rawValue)")
                }
            }
        }

        for (index, line) in lines.dropFirst().enumerated() {
            let lineNumber = index + 2 // +1 for header, +1 for 1-based indexing
            let cols = parseCSVLine(line)

            // 进度回调
            progressCallback?(index + 1, lines.count - 1)

            guard cols.count > max(dateColIndex, 1) else {
                Self.logger.warning("CSV import: skipping line \(lineNumber), not enough columns")
                continue
            }

            // Validate required field: date
            let dateString = cols[dateColIndex].trimmingCharacters(in: .whitespaces)
            guard dateString.isEmpty == false else {
                let msg = String(format: L10n.string("第 %d 行：缺少日期字段"), lineNumber)
                errors.append(msg)
                Self.logger.warning("CSV import: \(msg)")
                continue
            }

            guard let date = Self.parseCSVDate(dateString) else {
                errors.append(String(format: L10n.string("第 %d 行：无法解析日期: %@"), lineNumber, dateString))
                Self.logger.warning("CSV import: line \(lineNumber), unparseable date '\(dateString)'")
                continue
            }

            // Check for duplicate dates in the same import
            if duplicateDates.contains(date) {
                errors.append(String(format: L10n.string("第 %d 行：重复日期: %@"), lineNumber, dateString))
                Self.logger.warning("CSV import: line \(lineNumber), duplicate date '\(dateString)' in same import")
                continue
            }
            duplicateDates.insert(date)

            // Parse metrics with validation
            var metrics: [String: Double] = [:]
            var metricErrors: [String] = []

            for (colIdx, type) in metricMap where colIdx < cols.count {
                let valStr = cols[colIdx].trimmingCharacters(in: .whitespaces)
                guard !valStr.isEmpty else { continue }

                // Validate: must be a valid numeric value
                guard let val = Double(valStr) else {
                    metricErrors.append(String(format: L10n.string("%@ 格式错误: %@"), type.displayName, valStr))
                    Self.logger.warning("CSV import: line \(lineNumber), invalid numeric value '\(valStr)' for metric \(type.displayName)")
                    continue
                }

                // Validate value range
                let validRange = type.validRange
                if !validRange.contains(val) {
                    metricErrors.append(String(format: L10n.string("%@ 值超出合理范围 (%.1f-%.1f): %.1f"),
                                               type.displayName, validRange.lowerBound, validRange.upperBound, val))
                    Self.logger.warning("CSV import: line \(lineNumber), value \(val) out of range for \(type.displayName)")
                    continue
                }

                // Validate: duplicate entry (same date + metric already exists)
                let day = Calendar.current.startOfDay(for: date)
                let key = "\(day.timeIntervalSince1970)_\(type.rawValue)"
                if existingKeys.contains(key) {
                    let dupMsg = String(format: L10n.string("%@ 已存在相同日期的记录，已跳过"), type.displayName)
                    metricErrors.append(dupMsg)
                    Self.logger.warning("CSV import: line \(lineNumber), duplicate date+metric for \(type.displayName) on \(dateString)")
                    continue
                }

                metrics[type.rawValue] = val
            }

            if !metricErrors.isEmpty {
                errors.append(String(format: L10n.string("第 %d 行 (%@): %@"), lineNumber, dateString, metricErrors.joined(separator: "; ")))
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

            // Track imported keys to prevent duplicates within the same import
            let day = Calendar.current.startOfDay(for: date)
            for (rawKey, _) in metrics {
                existingKeys.insert("\(day.timeIntervalSince1970)_\(rawKey)")
            }
        }

        // 批量添加（只保存一次）
        if !parsedEntries.isEmpty {
            addEntries(parsedEntries)
        }

        if importedCount > 0 {
            Self.logger.info("CSV import completed: \(importedCount) entries imported, \(errors.count) errors")
            if errors.isEmpty {
                return (importedCount, nil)
            } else {
                let displayErrors = errors.prefix(3)
                var errorMsg = displayErrors.joined(separator: "\n")
                if errors.count > 3 {
                    errorMsg += String(format: L10n.string("\n...还有 %d 个错误"), errors.count - 3)
                }
                return (importedCount, errorMsg)
            }
        } else {
            Self.logger.error("CSV import failed: 0 entries imported, \(errors.count) errors")
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

    /// 预览 CSV 数据（导入前验证）
    /// - Returns: (预览数据行, 错误信息)
    func previewCSV(_ csvString: String, maxRows: Int = 10) -> (previewRows: [CSVPreviewRow], errors: [String]) {
        let lines = csvString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var previewRows: [CSVPreviewRow] = []
        var errors: [String] = []

        guard lines.count >= 2 else {
            errors.append(L10n.string("CSV 文件格式不正确，至少需要标题行和一行数据"))
            return ([], errors)
        }

        // Parse header
        let header = parseCSVLine(lines[0])
        let dateColIndex = header.firstIndex(where: {
            $0.contains("日期") || $0.contains("Date") || $0.contains("date")
        }) ?? 0

        // Build metric type mapping
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

        let noteColIndex = header.firstIndex(where: {
            $0.contains("备注") || $0.contains("Note") || $0.contains("note")
        })

        // Parse preview rows
        let linesToPreview = lines.dropFirst().prefix(maxRows)
        for (index, line) in linesToPreview.enumerated() {
            let lineNumber = index + 2
            let cols = parseCSVLine(line)

            guard cols.count > max(dateColIndex, 1) else {
                previewRows.append(CSVPreviewRow(lineNumber: lineNumber, date: nil, metrics: [:], note: nil, isValid: false))
                continue
            }

            // Parse date
            let dateString = cols[dateColIndex].trimmingCharacters(in: .whitespaces)
            let date = Self.parseCSVDate(dateString)

            // Parse metrics
            var metrics: [BodyMetricType: (value: Double, isValid: Bool)] = [:]
            for (colIdx, type) in metricMap where colIdx < cols.count {
                let valStr = cols[colIdx].trimmingCharacters(in: .whitespaces)
                guard !valStr.isEmpty else { continue }

                if let val = Double(valStr) {
                    let isValid = type.validRange.contains(val)
                    metrics[type] = (val, isValid)
                }
            }

            // Parse note
            var note: String? = nil
            if let nIdx = noteColIndex, nIdx < cols.count {
                let noteStr = cols[nIdx].trimmingCharacters(in: .whitespaces)
                if !noteStr.isEmpty { note = noteStr }
            }

            let isValid = date != nil && !metrics.isEmpty && metrics.values.allSatisfy { $0.isValid }
            previewRows.append(CSVPreviewRow(lineNumber: lineNumber, date: date, metrics: metrics, note: note, isValid: isValid))
        }

        // Check for overall issues
        if metricMap.isEmpty {
            errors.append(L10n.string("未找到有效的指标列"))
        }

        if previewRows.allSatisfy({ !$0.isValid }) {
            errors.append(L10n.string("预览的所有行都包含无效数据"))
        }

        return (previewRows, errors)
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
        exampleRow += ",\(L10n.string("笔记示例"))\n"
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
        // Debounce: cancel any pending save and schedule a new one after 100ms.
        // This avoids redundant writes when multiple mutations happen in quick succession.
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.saveDebounceInterval)
            guard !Task.isCancelled else { return }
            self?.performSave()
        }
    }

    /// Force an immediate save, bypassing the debounce mechanism.
    /// Use this when the app is about to enter background or terminate.
    func saveImmediately() {
        saveDebounceTask?.cancel()
        saveDebounceTask = nil
        performSave()
    }

    /// Replace all entries (used during backup restore). Sorts and saves immediately.
    func replaceEntries(_ newEntries: [BodyEntry]) {
        entries = newEntries
        sortEntries()
        invalidateStreakCache()
        saveImmediately()
    }

    private func performSave() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: Self.storeURL, options: [.atomic, .completeFileProtection])
            Self.logger.debug("Saved \(self.entries.count) entries (\(data.count) bytes)")
        } catch {
            let errorMsg = String(format: L10n.string("保存数据失败：%@\n\n提示：您的数据已被写入备份文件，但无法保存到主存储。"), error.localizedDescription)
            Self.logger.error("Save error: \(error.localizedDescription)")

            // 创建备份
            if let backupURL = createBackup() {
                Self.logger.info("Emergency backup created at: \(backupURL.path)")
            }

            // 触发错误回调
            if let errorHandler = saveErrorHandler {
                errorHandler(errorMsg)
            }
        }
    }

    private func createBackup() -> URL? {
        guard !entries.isEmpty else { return nil }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = Self.storeURL.deletingPathExtension()
            .appendingPathExtension("backup_\(timestamp).json")

        do {
            let data = try JSONEncoder().encode(entries)

            // Safety check: validate backup size is not unreasonably large (> 10MB)
            if data.count > Self.maxBackupSizeBytes {
                let sizeMB = Double(data.count) / (1024.0 * 1024.0)
                Self.logger.warning("Backup data is excessively large (\(String(format: "%.1f", sizeMB)) MB). Aborting backup creation to avoid disk pressure.")
                return nil
            }

            try data.write(to: backupURL, options: [.atomic, .completeFileProtection])
            Self.logger.info("Backup created: \(backupURL.lastPathComponent) (\(data.count) bytes)")
            return backupURL
        } catch {
            Self.logger.error("Backup creation error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Reload entries from disk (public, for pull-to-refresh)
    func reloadFromDisk() {
        load()
    }

    private func load() {
        // 检查是否有备份文件
        if let backupURL = findLatestBackup() {
            Self.logger.info("Found backup file: \(backupURL.path)")
            // 尝试从备份恢复
            if restoreFromBackup(backupURL) {
                let msg = String(format: L10n.string("已从备份恢复数据：\n%@", backupURL.lastPathComponent))
                if let errorHandler = loadErrorHandler {
                    errorHandler(msg)
                }
                return
            }
        }

        do {
            let data = try Data(contentsOf: Self.storeURL)
            entries = try JSONDecoder().decode([BodyEntry].self, from: data)
            sortEntries()
            Self.logger.info("Successfully loaded \(self.entries.count) entries")
        } catch {
            Self.logger.error("Load error: \(error.localizedDescription). Starting fresh with empty data.")

            let errorMsg = String(format: L10n.string("加载数据失败：%@\n\n提示：将使用空数据开始。"), error.localizedDescription)

            // Error recovery on corrupted data: clear the corrupted file
            entries = []
            do {
                // Move the corrupted file to a recovery name so it is not re-read
                let corruptedURL = Self.storeURL.deletingPathExtension()
                    .appendingPathExtension("corrupted_\(ISO8601DateFormatter().string(from: Date())).json")
                try FileManager.default.moveItem(at: Self.storeURL, to: corruptedURL)
                Self.logger.info("Corrupted data moved to: \(corruptedURL.path)")
            } catch {
                // If rename fails, try deleting
                try? FileManager.default.removeItem(at: Self.storeURL)
                Self.logger.warning("Could not rename corrupted file; attempted removal.")
            }

            // Notify user of the error recovery
            if let errorHandler = loadErrorHandler {
                errorHandler(errorMsg)
            }
        }
    }

    /// 查找最新的备份文件
    private func findLatestBackup() -> URL? {
        let dirURL = Self.storeURL.deletingLastPathComponent()

        let backupFiles: [URL]
        do {
            backupFiles = try FileManager.default.contentsOfDirectory(at: dirURL,
                                                                     includingPropertiesForKeys: nil,
                                                                     options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                .filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("backup_") }
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        } catch {
            return nil
        }

        return backupFiles.last
    }

    /// 从指定备份恢复
    private func restoreFromBackup(_ backupURL: URL) -> Bool {
        do {
            let data = try Data(contentsOf: backupURL)

            // Safety check: refuse to restore if backup is unreasonably large
            if data.count > Self.maxBackupSizeBytes {
                let sizeMB = Double(data.count) / (1024.0 * 1024.0)
                Self.logger.warning("Backup file is excessively large (\(String(format: "%.1f", sizeMB)) MB). Refusing restore.")
                return false
            }

            entries = try JSONDecoder().decode([BodyEntry].self, from: data)
            sortEntries()
            // 删除旧的备份文件，保留最新的一个
            let oldBackups = try? FileManager.default.contentsOfDirectory(at: backupURL.deletingLastPathComponent(),
                                                                          includingPropertiesForKeys: nil,
                                                                          options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                .filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("backup_") && $0 != backupURL }
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            oldBackups?.forEach { try? FileManager.default.removeItem(at: $0) }
            Self.logger.info("Successfully restored from backup: \(backupURL.lastPathComponent)")
            return true
        } catch {
            Self.logger.error("Restore from backup error: \(error.localizedDescription)")
            return false
        }
    }

    private func sortEntries() {
        entries.sort { $0.recordedAt > $1.recordedAt }
    }
}

// MARK: - CSV Preview Support

/// CSV 预览行数据结构
struct CSVPreviewRow: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let date: Date?
    let metrics: [BodyMetricType: (value: Double, isValid: Bool)]
    let note: String?
    let isValid: Bool
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
