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
    /// 内部渐变缓存字典
    /// 键：指标类型的原始值
    /// 值：对应的 LinearGradient 对象
    private static var gradientCache: [String: LinearGradient] = [:]
    
    /// 获取指定指标类型的渐变
    /// 如果缓存中已存在该指标类型的渐变，直接返回缓存的对象
    /// 否则创建新的渐变并添加到缓存中
    ///
    /// - Parameter metric: 指标类型，用于确定渐变对象
    /// - Returns: 对应的 LinearGradient 对象
    static func gradient(for metric: BodyMetricType) -> LinearGradient {
        let cacheKey = "gradient_\(metric.rawValue)"
        
        if let cached = gradientCache[cacheKey] {
            return cached
        }
        
        // 创建新的渐变对象
        let gradient = LinearGradient(
            colors: [.formlogPrimary.opacity(0.35), .formlogPrimary.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        gradientCache[cacheKey] = gradient
        return gradient
    }
    
    /// 清除所有缓存的渐变对象
    /// 当需要完全重置缓存时调用此方法
    /// 通常在内存压力较大或需要强制重新创建渐变时使用
    static func clearCache() {
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
    /// 内部格式化缓存字典
    /// 键：格式字符串 + 数值的组合，如 "%.1f_123.45"
    /// 值：格式化后的字符串
    private static var formatCache: [String: String] = [:]
    
    /// 格式化数值，使用缓存避免重复计算
    /// 如果缓存中已存在相同格式和数值的结果，直接返回缓存值
    /// 否则执行格式化并缓存结果
    ///
    /// - Parameters:
    ///   - value: 要格式化的数值
    ///   - format: 格式字符串，默认 "%.1f"（保留一位小数）
    /// - Returns: 格式化后的字符串
    /// - Note: 对于大量不同数值，缓存效率会降低，建议合理选择格式字符串
    static func format(_ value: Double, format: String = "%.1f") -> String {
        let cacheKey = "\(format)_\(value)"
        
        if let cached = formatCache[cacheKey] {
            return cached
        }
        
        let formatted = String(format: format, value)
        formatCache[cacheKey] = formatted
        return formatted
    }
    
    /// 清除所有缓存的格式化结果
    /// 当需要完全重置缓存时调用此方法
    static func clearCache() {
        formatCache.removeAll()
    }
}