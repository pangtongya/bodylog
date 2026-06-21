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
    
    /// 照片文件名（存储在 Documents/FormLogPhotos/ 目录）
    var photoFilename: String?

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        metrics: [String: Double] = [:],
        note: String? = nil,
        photoFilename: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.metrics = metrics
        self.note = note
        self.photoFilename = photoFilename
    }

    // MARK: - Photo Access
    
    /// 获取照片数据
    var loadedPhotoData: Data? {
        if let filename = photoFilename {
            return PhotoManager.shared.loadPhoto(filename: filename)
        }
        return nil
    }
    
    /// 是否有照片
    var hasPhoto: Bool {
        photoFilename != nil
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

    // MARK: - Equatable (比较所有业务字段，包括照片引用)
    static func == (lhs: BodyEntry, rhs: BodyEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.recordedAt == rhs.recordedAt &&
        lhs.metrics == rhs.metrics &&
        lhs.note == rhs.note &&
        lhs.photoFilename == rhs.photoFilename
    }
}
