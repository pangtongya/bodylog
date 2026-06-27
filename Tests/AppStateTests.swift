// AppStateTests.swift
// AppState 单元测试

import XCTest
@testable import FormLog

@preconcurrency
final class AppStateTests: XCTestCase {
    
    var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = MainActor.assumeIsolated { AppState.shared }
        MainActor.assumeIsolated {
            appState.enabledMetrics.removeAll()
            appState.disabledMetrics.removeAll()
            appState.weightUnit = .kg
        }
    }
    
    override func tearDown() {
        MainActor.assumeIsolated { appState = nil }
        super.tearDown()
    }
    
    // MARK: - 基本功能测试
    
    @MainActor func testInitialState() {
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count)
        XCTAssertEqual(appState.weightUnit, .kg)
        XCTAssertFalse(appState.isPro)
    }
    
    @MainActor func testToggleMetric() {
        let metric = BodyMetricType.weight

        // 启用指标
        appState.enabledMetrics.append(metric)
        XCTAssertTrue(appState.enabledMetrics.contains(metric))
        XCTAssertEqual(appState.enabledMetrics.count, 1)

        // 禁用指标
        appState.enabledMetrics.removeAll { $0 == metric }
        XCTAssertFalse(appState.enabledMetrics.contains(metric))
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
    }
    
    @MainActor func testEnableAllMetrics() {
        appState.enabledMetrics = BodyMetricType.allCases
        XCTAssertEqual(appState.enabledMetrics.count, BodyMetricType.allCases.count)
    }

    @MainActor func testDisableAllMetrics() {
        appState.enabledMetrics = BodyMetricType.allCases
        appState.enabledMetrics.removeAll()
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
    }
    
    // MARK: - 数据验证测试
    
    @MainActor func testValidateEnabledMetrics_InvalidValues() {
        // BodyMetricType is a String-backed enum; invalid raw values cannot
        // exist as enum instances. Simulate by setting an empty list and
        // verifying that validateAllMetrics() restores the defaults.
        appState.enabledMetrics = []

        let isValid = appState.validateAllMetrics()
        // Empty enabled list is treated as invalid (defaults are restored)
        XCTAssertFalse(isValid)
        // After validation, defaults should be restored
        XCTAssertEqual(appState.enabledMetrics.count, 2)
    }
    
    @MainActor func testValidateEnabledMetrics_ValidValues() {
        // 测试有效的启用指标数据
        appState.enabledMetrics = [.weight, .bodyFat]

        let isValid = appState.validateAllMetrics()
        XCTAssertTrue(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 2)
    }
    
    @MainActor func testValidateDisabledMetrics_InvalidValues() {
        // BodyMetricType enum cannot hold invalid values.
        // Simulate inconsistency: enable one metric, then set disabledMetrics
        // to also contain that metric to test consistency validation.
        appState.enabledMetrics = [.weight]
        appState.disabledMetrics = BodyMetricType.allCases // includes .weight

        let isValid = appState.validateAllMetrics()
        // Data was inconsistent (weight in both lists), so validation returns false
        XCTAssertFalse(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        // After validation, disabled should exclude enabled metrics
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
    }
    
    @MainActor func testValidateDisabledMetrics_ValidValues() {
        // 测试有效的禁用指标数据
        appState.enabledMetrics = [.weight]

        let isValid = appState.validateAllMetrics()
        XCTAssertTrue(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        // disabledMetrics is auto-derived from enabledMetrics
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
    }
    
    @MainActor func testValidateAllMetrics() {
        // Set up inconsistency: enable weight, then also put it in disabled list
        appState.enabledMetrics = [.weight]
        appState.disabledMetrics = [.weight, .bodyFat] // weight duplicated

        let isValid = appState.validateAllMetrics()
        // Validation detected inconsistency and returns false
        XCTAssertFalse(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        // disabledMetrics is auto-derived, excludes enabled
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
    }
    
    // MARK: - 重量单位转换测试
    
    @MainActor func testDisplayWeight_KgToLb() {
        appState.weightUnit = .lb
        let weight = 70.0 // kg
        let display = appState.displayWeight(weight)
        
        XCTAssertEqual(display.unit, "lb")
        XCTAssertEqual(display.value, weight * 2.20462, accuracy: 0.01)
    }
    
    @MainActor func testDisplayWeight_KgToKg() {
        appState.weightUnit = .kg
        let weight = 70.0 // kg
        let display = appState.displayWeight(weight)
        
        XCTAssertEqual(display.unit, "kg")
        XCTAssertEqual(display.value, weight, accuracy: 0.01)
    }
    
    @MainActor func testDisplayWeight_LbToKg() {
        // Test lb-to-kg conversion using WeightUnit.convert
        let lbValue = 154.0
        let kgValue = AppState.WeightUnit.kg.convert(lbValue, from: .lb)

        XCTAssertEqual(kgValue, lbValue / 2.20462, accuracy: 0.01)
    }
    
    // MARK: - 备份和恢复测试
    
    @MainActor func testBackup() {
        // 设置一些测试数据
        appState.enabledMetrics = [.weight, .bodyFat]
        appState.weightUnit = .lb
        appState.isPro = true

        let backupData = appState.encodeForBackup()

        XCTAssertFalse(backupData.isEmpty)
        // Verify the backup can be restored
        let success = appState.restoreFromBackup(backupData)
        XCTAssertTrue(success)
        XCTAssertEqual(appState.enabledMetrics.count, 2)
        XCTAssertEqual(appState.weightUnit, .lb)
    }
    
    @MainActor func testRestoreFromBackup_Valid() {
        // 创建备份数据：先 set up state, encode it, then reset and restore
        appState.enabledMetrics = [.weight, .muscleMass]
        appState.weightUnit = .kg
        appState.isPro = false
        let backupData = appState.encodeForBackup()

        // Reset state
        appState.enabledMetrics.removeAll()
        appState.weightUnit = .lb
        appState.isPro = true

        // 恢复
        let success = appState.restoreFromBackup(backupData)
        XCTAssertTrue(success)
        XCTAssertEqual(appState.enabledMetrics.count, 2)
        XCTAssertEqual(appState.weightUnit, .kg)
        XCTAssertFalse(appState.isPro)
    }
    
    @MainActor func testRestoreFromBackup_Invalid() {
        // 创建包含无效数据的备份（corrupt JSON that fails decoding）
        let invalidBackupData = Data("{\"schemaVersion\":1,\"enabledMetrics\":[\"invalid_metric\"],\"weightUnit\":\"kg\"}".utf8)

        // 尝试恢复应该失败
        // Note: BodyMetricType decoding will fail for "invalid_metric",
        // causing JSONDecoder to throw, so restoreFromBackup returns false.
        let success = appState.restoreFromBackup(invalidBackupData)
        XCTAssertFalse(success)
    }
    
    @MainActor func testRestoreFromBackup_WithValidation() {
        // 创建一个有效的备份，恢复后手动制造不一致，再验证
        appState.enabledMetrics = [.weight, .muscleMass]
        appState.weightUnit = .kg
        let backupData = appState.encodeForBackup()

        // Reset and restore
        appState.enabledMetrics.removeAll()
        _ = appState.restoreFromBackup(backupData)

        // Manually introduce inconsistency (same metric in both lists)
        appState.disabledMetrics = [.weight, .bodyFat]

        // validateAllMetrics should fix the inconsistency
        let isValid = appState.validateAllMetrics()
        XCTAssertFalse(isValid) // data was inconsistent
        XCTAssertEqual(appState.enabledMetrics.count, 2)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 2)
    }
    
    // MARK: - 数据完整性测试
    
    @MainActor func testDataConsistency() {
        // 初始状态应该是一致的（no overlap between enabled and disabled）
        let initialOverlap = appState.enabledMetrics.contains { appState.disabledMetrics.contains($0) }
        XCTAssertFalse(initialOverlap)

        // 设置全部启用后也应该一致
        appState.enabledMetrics = BodyMetricType.allCases
        appState.disabledMetrics.removeAll()
        let afterEnableOverlap = appState.enabledMetrics.contains { appState.disabledMetrics.contains($0) }
        XCTAssertFalse(afterEnableOverlap)

        // 手动破坏一致性
        appState.enabledMetrics = [.weight]
        appState.disabledMetrics = [.weight, .bodyFat] // weight 同时出现在两个数组中
        let brokenOverlap = appState.enabledMetrics.contains { appState.disabledMetrics.contains($0) }
        XCTAssertTrue(brokenOverlap)

        // 修复一致性
        _ = appState.validateAllMetrics()
        let fixedOverlap = appState.enabledMetrics.contains { appState.disabledMetrics.contains($0) }
        XCTAssertFalse(fixedOverlap)
    }
    
    // MARK: - 性能测试
    
    @MainActor func testPerformanceToggleMetrics() {
        measure {
            for _ in 0..<1000 {
                appState.enabledMetrics.append(.weight)
                appState.enabledMetrics.removeAll { $0 == .weight }
                appState.enabledMetrics.append(.bodyFat)
                appState.enabledMetrics.removeAll { $0 == .bodyFat }
            }
        }
    }
    
    @MainActor func testPerformanceValidation() {
        // 设置大量数据
        appState.enabledMetrics = BodyMetricType.allCases
        appState.disabledMetrics = []
        
        measure {
            _ = appState.validateAllMetrics()
        }
    }
}
