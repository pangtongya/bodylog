// BodyEntryStore.swift
// 身体数据记录管理

import Foundation
import SwiftUI

@MainActor
class BodyEntryStore: ObservableObject {
    @Published var entries: [BodyEntry] = []

    private var saveWorkItem: DispatchWorkItem?

    private static let storeURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("body_entries.json")
    }()

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

    /// 最新一条记录
    var latestEntry: BodyEntry? { entries.first }

    /// 按日期分组的记录（Dictionary<String, [BodyEntry]>）
    var groupedByDate: [(key: String, value: [BodyEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        let calendar = Calendar.current
        // Group by start-of-day Date to enable fast Date-based sorting
        let grouped = Dictionary(grouping: entries) { entry -> Date in
            calendar.startOfDay(for: entry.recordedAt)
        }
        // Sort descending by date (newest first), then format key for display
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: formatter.string(from: $0.key), value: $0.value) }
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

    /// 变化量（最新 - 最早）
    func totalChange(for type: BodyMetricType) -> Double? {
        guard let latest = latestValue(for: type),
              let start = startValue(for: type),
              latest != start else { return nil }
        return latest - start
    }

    /// 30天变化量（最新 vs 30天前最近一条）
    func change30Days(for type: BodyMetricType) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        guard let latest = latestValue(for: type) else { return nil }
        let old = entries.filter { $0.recordedAt <= cutoff }
            .first { $0.value(for: type) != nil }
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

    /// 连续记录天数（streak）
    var currentStreak: Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let recordedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.recordedAt) })

        while recordedDays.contains(checkDate) {
            streak += 1
            checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    // MARK: - Export / Import / Backup

    /// 生成 CSV 字符串（所有已记录指标）
    func exportCSV() -> String {
        let allMetrics = BodyMetricType.allCases
        let header = (["日期"] + allMetrics.map { $0.displayName + "(\($0.unit))" } + ["备注"]).joined(separator: ",")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let rows = entries.map { entry -> String in
            let date = formatter.string(from: entry.recordedAt)
            let values = allMetrics.map { type -> String in
                if let v = entry.value(for: type) {
                    return String(format: "%.2f", v)
                }
                return ""
            }
            let note = entry.note?.replacingOccurrences(of: ",", with: "，") ?? ""
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
            return (0, "CSV 文件格式不正确，至少需要标题行和一行数据")
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "yyyy-MM-dd"
        
        for line in lines.dropFirst() {
            let cols = parseCSVLine(line)
            
            guard cols.count > max(dateColIndex, 1) else { continue }
            
            // Parse date
            let dateString = cols[dateColIndex].trimmingCharacters(in: .whitespaces)
            guard let date = dateFormatter.date(from: dateString) ??
                          shortDateFormatter.date(from: dateString) else {
                errors.append("无法解析日期: \(dateString)")
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
            addEntry(entry)
            importedCount += 1
        }
        
        save()
        
        if importedCount > 0 {
            return (importedCount, errors.isEmpty ? nil : "\(errors.count) 行数据跳过")
        } else {
            return (0, errors.isEmpty ? "未找到有效数据" : errors.first)
        }
    }
    
    /// 简单的 CSV 行解析（处理逗号分隔，不支持引号包裹）
    private func parseCSVLine(_ line: String) -> [String] {
        line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    // MARK: - Persistence
    
    func save() {
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
            
            // 迁移旧数据：photoData (Data?) → photoFilename (String?)
            migrateLegacyPhotos()
        } catch {
            entries = []
        }
    }
    
    /// 迁移旧格式的照片数据到文件存储
    private func migrateLegacyPhotos() {
        var needsSave = false
        for idx in entries.indices {
            // 只迁移有photoData但没有photoFilename的entry
            if entries[idx].photoData != nil && entries[idx].photoFilename == nil,
               let filename = PhotoManager.shared.migrate(photoData: entries[idx].photoData) {
                entries[idx].photoFilename = filename
                entries[idx].photoData = nil  // 清除旧数据
                needsSave = true
            }
        }
        if needsSave {
            performSave()
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
