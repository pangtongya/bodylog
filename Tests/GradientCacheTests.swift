// GradientCacheTests.swift
// GradientCache 性能优化单元测试

import XCTest
import SwiftUI
@testable import FormLog

@preconcurrency
final class GradientCacheTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // 清除缓存以获得可预测的测试结果
        MainActor.assumeIsolated {
            GradientCache.clearCache()
            StringFormatCache.clearCache()
        }
    }
    
    override func tearDown() {
        // 清除缓存
        MainActor.assumeIsolated {
            GradientCache.clearCache()
            StringFormatCache.clearCache()
        }
        super.tearDown()
    }
    
    // MARK: - GradientCache 测试
    
    @MainActor func testGradientCache_Hit() {
        _ = GradientCache.gradient(for: .weight)
        XCTAssertEqual(getGradientCacheCount(), 1)
        // Second call should not increase cache
        _ = GradientCache.gradient(for: .weight)
        XCTAssertEqual(getGradientCacheCount(), 1)
    }
    
    @MainActor func testGradientCache_Miss() {
        _ = GradientCache.gradient(for: .weight)
        XCTAssertEqual(getGradientCacheCount(), 1)
        _ = GradientCache.gradient(for: .bodyFat)
        XCTAssertEqual(getGradientCacheCount(), 2)
    }
    
    @MainActor func testGradientCache_CacheCount() {
        // 添加几个不同的渐变到缓存
        _ = GradientCache.gradient(for: .weight)
        _ = GradientCache.gradient(for: .bodyFat)
        _ = GradientCache.gradient(for: .muscleMass)
        
        // 验证缓存中有 3 个条目
        let cacheCount = getGradientCacheCount()
        XCTAssertEqual(cacheCount, 3)
    }
    
    @MainActor func testGradientCache_Clear() {
        // 先添加渐变到缓存
        _ = GradientCache.gradient(for: .weight)
        XCTAssertEqual(getGradientCacheCount(), 1)
        
        // 清除缓存
        GradientCache.clearCache()
        XCTAssertEqual(getGradientCacheCount(), 0)
    }
    
    // MARK: - StringFormatCache 测试
    
    @MainActor func testStringFormatCache_Hit() {
        // 相同的格式和值应该被缓存
        let formatted1 = StringFormatCache.format(3.14159, format: "%.2f")
        let formatted2 = StringFormatCache.format(3.14159, format: "%.2f")
        
        XCTAssertEqual(formatted1, "3.14")
        XCTAssertEqual(formatted2, "3.14")
    }
    
    @MainActor func testStringFormatCache_DifferentFormats() {
        // 相同的值，不同的格式
        let formatted1 = StringFormatCache.format(3.14159, format: "%.1f")
        let formatted2 = StringFormatCache.format(3.14159, format: "%.2f")
        
        XCTAssertEqual(formatted1, "3.1")
        XCTAssertEqual(formatted2, "3.14")
    }
    
    @MainActor func testStringFormatCache_DifferentValues() {
        // 不同的值，相同的格式
        let formatted1 = StringFormatCache.format(1.23, format: "%.1f")
        let formatted2 = StringFormatCache.format(4.56, format: "%.1f")
        
        XCTAssertEqual(formatted1, "1.2")
        XCTAssertEqual(formatted2, "4.6")
    }
    
    @MainActor func testStringFormatCache_CacheCount() {
        // 添加不同的格式化结果到缓存
        _ = StringFormatCache.format(1.0, format: "%.0f")
        _ = StringFormatCache.format(1.0, format: "%.1f")
        _ = StringFormatCache.format(2.0, format: "%.0f")
        
        let cacheCount = getStringFormatCacheCount()
        XCTAssertEqual(cacheCount, 3)
    }
    
    @MainActor func testStringFormatCache_Clear() {
        // 先添加格式化结果到缓存
        _ = StringFormatCache.format(1.0, format: "%.1f")
        XCTAssertEqual(getStringFormatCacheCount(), 1)
        
        // 清除缓存
        StringFormatCache.clearCache()
        XCTAssertEqual(getStringFormatCacheCount(), 0)
    }
    
    // MARK: - 性能测试
    
    @MainActor func testGradientCachePerformance() {
        // 测试缓存的性能优势
        measure {
            for _ in 0..<1000 {
                _ = GradientCache.gradient(for: .weight)
            }
        }
    }
    
    @MainActor func testStringFormatCachePerformance() {
        // 测试字符串格式化缓存的性能优势
        measure {
            for i in 0..<1000 {
                _ = StringFormatCache.format(Double(i), format: "%.2f")
            }
        }
    }
    
    @MainActor func testCacheMissPerformance() {
        // 测试没有缓存的性能（用于对比）
        measure {
            for _ in 0..<1000 {
                _ = LinearGradient(
                    colors: [Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.35), Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    // MARK: - 边界情况测试
    
    @MainActor func testStringFormatCache_ZeroValue() {
        let formatted = StringFormatCache.format(0.0, format: "%.1f")
        XCTAssertEqual(formatted, "0.0")
    }
    
    @MainActor func testStringFormatCache_NegativeValue() {
        let formatted = StringFormatCache.format(-1.5, format: "%.1f")
        XCTAssertEqual(formatted, "-1.5")
    }
    
    @MainActor func testStringFormatCache_LargeValue() {
        let formatted = StringFormatCache.format(999999.999, format: "%.1f")
        XCTAssertEqual(formatted, "1000000.0")
    }
    
    // MARK: - 私有辅助方法
    
    private func getGradientCacheCount() -> Int {
        // 通过反射访问私有缓存（仅用于测试）
        return Mirror(reflecting: GradientCache.self)
            .children
            .compactMap { $0.label == "gradientCache" ? $0.value as? [String: Any] : nil }
            .first?.count ?? 0
    }
    
    private func getStringFormatCacheCount() -> Int {
        // 通过反射访问私有缓存（仅用于测试）
        return Mirror(reflecting: StringFormatCache.self)
            .children
            .compactMap { $0.label == "formatCache" ? $0.value as? [String: Any] : nil }
            .first?.count ?? 0
    }
}
