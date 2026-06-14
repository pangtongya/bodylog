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
        entries.removeAll { $0.id == id }
        save()
    }

    func deleteEntries(at offsets: IndexSet) {
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

    // MARK: - Export

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
