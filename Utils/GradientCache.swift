// GradientCache.swift
// 图表渲染性能优化工具
// 提供渐变对象和字符串格式化结果的缓存机制，减少重复计算和内存分配

import SwiftUI

/// 图表渐变缓存
/// 缓存图表使用的渐变对象，避免在每次渲染时重复创建相同的 LinearGradient
/// 这对于频繁重绘的图表（如趋势图）有显著的性能提升
///
/// # 使用场景
/// - 趋势图（TrendView）中的 AreaMark 使用
/// - 大数据集（100+ 个数据点）减少渐变对象创建开销
///
/// # 性能优化原理
/// - 每个指标类型使用相同的渐变，因此通过 metric.rawValue 作为缓存键
/// - 渐变对象是昂贵的，创建后会长期缓存，直到手动清除
/// - 避免在 body 渲染循环中创建新对象，降低 CPU 负载
///
/// # 线程安全
/// - 所有操作都是静态方法，在调用处确保线程安全
/// - 不依赖实例状态，因此没有竞态条件风险
struct GradientCache {
    @MainActor private static var gradientCache: [String: LinearGradient] = [:]
    
    @MainActor static func gradient(for metric: BodyMetricType) -> LinearGradient {
        let cacheKey = "gradient_\(metric.rawValue)"
        
        if let cached = gradientCache[cacheKey] {
            return cached
        }
        
        let gradient = LinearGradient(
            colors: [metric.color.opacity(0.35), metric.color.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        gradientCache[cacheKey] = gradient
        return gradient
    }
    
    @MainActor static func clearCache() {
        gradientCache.removeAll()
    }
}

/// 字符串格式化缓存
/// 缓存常见的字符串格式化结果，避免在循环中重复执行 String(format:) 操作
///
/// # 使用场景
/// - 统计数据显示（最新值、变化值等）
/// - 数字格式化（保留小数位、千位分隔符等）
///
/// # 性能优化原理
/// - 使用格式字符串和数值作为组合键，避免重复计算
/// - 格式化操作在 CPU 密集型场景（如大数据列表）中开销显著
/// - 缓存后每次访问都是 O(1) 的哈希表查找
///
/// # 线程安全
/// - 所有操作都是静态方法，在调用处确保线程安全
/// - 不依赖实例状态，因此没有竞态条件风险
struct StringFormatCache {
    @MainActor private static var formatCache: [String: String] = [:]
    
    @MainActor static func format(_ value: Double, format: String = "%.1f") -> String {
        let cacheKey = "\(format)_\(value)"
        
        if let cached = formatCache[cacheKey] {
            return cached
        }
        
        let formatted = String(format: format, value)
        formatCache[cacheKey] = formatted
        return formatted
    }
    
    @MainActor static func clearCache() {
        formatCache.removeAll()
    }
}