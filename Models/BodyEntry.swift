// BodyEntry.swift
// 单次身体数据记录

import Foundation

/// 一次身体数据记录，包含多个指标值
struct BodyEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var recordedAt: Date
    var metrics: [String: Double]   // BodyMetricType.rawValue -> value
    var note: String?
    
    // MARK: - Photo Storage
    
    /// 新格式：照片文件名（存储在 Documents/BodyLogPhotos/ 目录）
    var photoFilename: String?
    
    /// 旧格式：照片数据（向后兼容，新代码不再使用此字段写入，仅在迁移时读取）
    var photoData: Data?

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        metrics: [String: Double] = [:],
        note: String? = nil,
        photoData: Data? = nil,
        photoFilename: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.metrics = metrics
        self.note = note
        self.photoData = photoData
        self.photoFilename = photoFilename
    }

    // MARK: - Photo Access
    
    /// 获取照片数据（优先从文件加载，兼容旧格式）
    var loadedPhotoData: Data? {
        // 新格式：从文件加载
        if let filename = photoFilename {
            return PhotoManager.shared.loadPhoto(filename: filename)
        }
        // 旧格式：返回内存中的数据（用于迁移）
        return photoData
    }
    
    /// 是否有照片
    var hasPhoto: Bool {
        photoFilename != nil || (photoData != nil && (photoData?.count ?? 0) > 1000)
    }

    // MARK: - Helpers

    func value(for type: BodyMetricType) -> Double? {
        metrics[type.rawValue]
    }

    mutating func setValue(_ value: Double, for type: BodyMetricType) {
        metrics[type.rawValue] = value
    }

    mutating func removeValue(for type: BodyMetricType) {
        metrics.removeValue(forKey: type.rawValue)
    }

    var hasAnyMetric: Bool {
        !metrics.isEmpty
    }

    /// 主要显示指标（优先体重）
    var primaryMetric: (type: BodyMetricType, value: Double)? {
        let priority: [BodyMetricType] = [.weight, .bodyFat, .muscleMass, .bmi]
        for t in priority {
            if let v = value(for: t) { return (t, v) }
        }
        if let first = metrics.first,
           let t = BodyMetricType(rawValue: first.key) {
            return (t, first.value)
        }
        return nil
    }

    // MARK: - Equatable (忽略 photoData 大字段，仅比较业务字段)
    static func == (lhs: BodyEntry, rhs: BodyEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.recordedAt == rhs.recordedAt &&
        lhs.metrics == rhs.metrics &&
        lhs.note == rhs.note
    }
}
