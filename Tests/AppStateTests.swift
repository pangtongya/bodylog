// AppStateTests.swift
// AppState 单元测试

import XCTest
@testable import FormLog

@MainActor
final class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
        // 清空数据开始测试
        appState.enabledMetrics.removeAll()
        appState.disabledMetrics.removeAll()
        appState.weightUnit = .kg
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - 基本功能测试
    
    func testInitialState() {
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count)
        XCTAssertEqual(appState.weightUnit, .kg)
        XCTAssertFalse(appState.hasProFeatures)
    }
    
    func testToggleMetric() {
        let metric = BodyMetricType.weight
        
        // 启用指标
        appState.toggleMetric(metric)
        XCTAssertTrue(appState.isEnabled(metric))
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
        
        // 禁用指标
        appState.toggleMetric(metric)
        XCTAssertFalse(appState.isEnabled(metric))
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count)
    }
    
    func testEnableAllMetrics() {
        appState.enableAllMetrics()
        XCTAssertEqual(appState.enabledMetrics.count, BodyMetricType.allCases.count)
        XCTAssertTrue(appState.disabledMetrics.isEmpty)
    }
    
    func testDisableAllMetrics() {
        appState.enableAllMetrics()
        appState.disableAllMetrics()
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count)
    }
    
    // MARK: - 数据验证测试
    
    func testValidateEnabledMetrics_InvalidValues() {
        // 测试无效的启用指标数据
        appState.enabledMetrics = ["invalid_metric"] as! [BodyMetricType]
        
        let isValid = appState.validateEnabledMetrics()
        XCTAssertFalse(isValid)
        XCTAssertTrue(appState.enabledMetrics.isEmpty) // 应该被清空
    }
    
    func testValidateEnabledMetrics_ValidValues() {
        // 测试有效的启用指标数据
        appState.enabledMetrics = [.weight, .bodyFat]
        
        let isValid = appState.validateEnabledMetrics()
        XCTAssertTrue(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 2)
    }
    
    func testValidateDisabledMetrics_InvalidValues() {
        // 测试无效的禁用指标数据
        appState.enabledMetrics = [.weight]
        appState.disabledMetrics = ["invalid_metric"] as! [BodyMetricType]
        
        let isValid = appState.validateDisabledMetrics()
        XCTAssertFalse(isValid)
        // 无效值应该被移除，但有效的应该保留
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
    }
    
    func testValidateDisabledMetrics_ValidValues() {
        // 测试有效的禁用指标数据
        appState.enabledMetrics = [.weight]
        appState.disabledMetrics = [.bodyFat, .muscleMass]
        
        let isValid = appState.validateDisabledMetrics()
        XCTAssertTrue(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        XCTAssertEqual(appState.disabledMetrics.count, 2)
    }
    
    func testValidateAllMetrics() {
        // 混合有效和无效数据
        appState.enabledMetrics = [.weight, "invalid_metric"] as! [BodyMetricType]
        appState.disabledMetrics = [.bodyFat, "another_invalid"] as! [BodyMetricType]
        
        let isValid = appState.validateAllMetrics()
        XCTAssertTrue(isValid)
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
    }
    
    // MARK: - 重量单位转换测试
    
    func testDisplayWeight_KgToLb() {
        appState.weightUnit = .lb
        let weight = 70.0 // kg
        let display = appState.displayWeight(weight)
        
        XCTAssertEqual(display.unit, "lb")
        XCTAssertEqual(display.value, weight * 2.20462, accuracy: 0.01)
    }
    
    func testDisplayWeight_KgToKg() {
        appState.weightUnit = .kg
        let weight = 70.0 // kg
        let display = appState.displayWeight(weight)
        
        XCTAssertEqual(display.unit, "kg")
        XCTAssertEqual(display.value, weight, accuracy: 0.01)
    }
    
    func testDisplayWeight_LbToKg() {
        appState.weightUnit = .kg
        let weight = 154.0 // lb
        let display = appState.displayWeight(weight, from: .lb)
        
        XCTAssertEqual(display.unit, "kg")
        XCTAssertEqual(display.value, weight / 2.20462, accuracy: 0.01)
    }
    
    // MARK: - 备份和恢复测试
    
    func testBackup() {
        // 设置一些测试数据
        appState.enabledMetrics = [.weight, .bodyFat]
        appState.weightUnit = .lb
        appState.hasProFeatures = true
        
        let backup = appState.backup()
        
        XCTAssertEqual(backup.enabledMetrics.count, 2)
        XCTAssertEqual(backup.disabledMetrics.count, BodyMetricType.allCases.count - 2)
        XCTAssertEqual(backup.weightUnit, .lb)
        XCTAssertTrue(backup.hasProFeatures)
    }
    
    func testRestoreFromBackup_Valid() {
        // 创建备份
        let backup = AppState.Backup(
            enabledMetrics: [.weight, .muscleMass],
            disabledMetrics: [.bodyFat, .waist],
            weightUnit: .kg,
            hasProFeatures: false
        )
        
        // 恢复
        let success = appState.restoreFromBackup(backup)
        XCTAssertTrue(success)
        XCTAssertEqual(appState.enabledMetrics.count, 2)
        XCTAssertEqual(appState.disabledMetrics.count, 2)
        XCTAssertEqual(appState.weightUnit, .kg)
        XCTAssertFalse(appState.hasProFeatures)
    }
    
    func testRestoreFromBackup_Invalid() {
        // 创建包含无效数据的备份
        let invalidBackup = AppState.Backup(
            enabledMetrics: ["invalid_metric"] as! [BodyMetricType],
            disabledMetrics: ["another_invalid"] as! [BodyMetricType],
            weightUnit: .kg,
            hasProFeatures: false
        )
        
        // 尝试恢复应该失败并清理数据
        let success = appState.restoreFromBackup(invalidBackup)
        XCTAssertFalse(success)
        XCTAssertTrue(appState.enabledMetrics.isEmpty)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count)
    }
    
    func testRestoreFromBackup_WithValidation() {
        // 创建部分无效的备份
        let partialInvalidBackup = AppState.Backup(
            enabledMetrics: [.weight, "invalid_metric"] as! [BodyMetricType],
            disabledMetrics: [.bodyFat, "another_invalid"] as! [BodyMetricType],
            weightUnit: .kg,
            hasProFeatures: false
        )
        
        // 恢复应该成功，但会清理无效数据
        let success = appState.restoreFromBackup(partialInvalidBackup)
        XCTAssertTrue(success)
        XCTAssertEqual(appState.enabledMetrics.count, 1)
        XCTAssertEqual(appState.disabledMetrics.count, BodyMetricType.allCases.count - 1)
    }
    
    // MARK: - 数据完整性测试
    
    func testDataConsistency() {
        // 初始状态应该是一致的
        XCTAssertTrue(appState.isDataConsistent())
        
        // 添加指标后应该保持一致
        appState.enableAllMetrics()
        XCTAssertTrue(appState.isDataConsistent())
        
        // 手动破坏一致性
        appState.enabledMetrics = [.weight]
        appState.disabledMetrics = [.weight, .bodyFat] // weight 同时出现在两个数组中
        XCTAssertFalse(appState.isDataConsistent())
        
        // 修复一致性
        appState.validateAllMetrics()
        XCTAssertTrue(appState.isDataConsistent())
    }
    
    // MARK: - 性能测试
    
    func testPerformanceToggleMetrics() {
        measure {
            for _ in 0..<1000 {
                appState.toggleMetric(.weight)
                appState.toggleMetric(.bodyFat)
            }
        }
    }
    
    func testPerformanceValidation() {
        // 设置大量数据
        appState.enabledMetrics = BodyMetricType.allCases
        appState.disabledMetrics = []
        
        measure {
            _ = appState.validateAllMetrics()
        }
    }
}