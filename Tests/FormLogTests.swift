// FormLogTests.swift
// FormLog 单元测试

import XCTest
@testable import FormLog

@preconcurrency
final class FormLogTests: XCTestCase {

    var entryStore: BodyEntryStore!
    var goalStore: GoalStore!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            entryStore = BodyEntryStore()
            entryStore.entries = []
            goalStore = GoalStore()
            goalStore.goals = []
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            entryStore = nil
            goalStore = nil
        }
        super.tearDown()
    }

    // MARK: - BodyEntry Model Tests

    @MainActor func testBodyEntryCreation() {
        let entry = BodyEntry(metrics: ["weight": 70.0])
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.value(for: .weight), 70.0)
        XCTAssertTrue(entry.hasAnyMetric)
    }

    @MainActor func testBodyEntrySetValue() {
        var entry = BodyEntry()
        entry.setValue(25.5, for: .bodyFat)
        XCTAssertEqual(entry.value(for: .bodyFat), 25.5)
        entry.removeValue(for: .bodyFat)
        XCTAssertNil(entry.value(for: .bodyFat))
    }

    @MainActor func testBodyEntryPrimaryMetric() {
        let entry = BodyEntry(metrics: ["weight": 75.0, "bodyFat": 20.0])
        XCTAssertEqual(entry.primaryMetric?.type, .weight)
    }

    @MainActor func testBodyEntryEquatable() {
        let e1 = BodyEntry(id: UUID(), metrics: ["weight": 70.0])
        let e2 = BodyEntry(id: e1.id, recordedAt: e1.recordedAt, metrics: ["weight": 70.0])
        XCTAssertEqual(e1, e2)
    }

    // MARK: - BodyEntryStore CRUD Tests

    @MainActor func testAddEntry() {
        let entry = BodyEntry(metrics: ["weight": 68.0])
        entryStore.addEntry(entry)
        XCTAssertEqual(entryStore.entries.count, 1)
        XCTAssertEqual(entryStore.entries.first?.value(for: .weight), 68.0)
    }

    @MainActor func testUpdateEntry() {
        var entry = BodyEntry(metrics: ["weight": 68.0])
        entryStore.addEntry(entry)
        entry.setValue(67.5, for: .weight)
        entryStore.updateEntry(entry)
        XCTAssertEqual(entryStore.entries.first?.value(for: .weight), 67.5)
    }

    @MainActor func testDeleteEntry() {
        let entry = BodyEntry(metrics: ["weight": 68.0])
        entryStore.addEntry(entry)
        entryStore.deleteEntry(id: entry.id)
        XCTAssertTrue(entryStore.entries.isEmpty)
    }

    @MainActor func testEntriesSortedByDate() {
        let older = BodyEntry(recordedAt: Date().addingTimeInterval(-86400), metrics: ["weight": 70.0])
        let newer = BodyEntry(recordedAt: Date(), metrics: ["weight": 69.0])
        entryStore.addEntry(older)
        entryStore.addEntry(newer)
        XCTAssertEqual(entryStore.entries.first?.value(for: .weight), 69.0) // newest first
    }

    // MARK: - BodyEntryStore Query Tests

    @MainActor func testLatestValue() {
        let e1 = BodyEntry(recordedAt: Date().addingTimeInterval(-100), metrics: ["weight": 72.0])
        let e2 = BodyEntry(recordedAt: Date(), metrics: ["weight": 70.0])
        entryStore.addEntry(e1)
        entryStore.addEntry(e2)
        XCTAssertEqual(entryStore.latestValue(for: .weight), 70.0)
    }

    @MainActor func testTotalChange() {
        // Start: 75, Latest: 70, change = -5
        let start = BodyEntry(recordedAt: Date().addingTimeInterval(-86400 * 30), metrics: ["weight": 75.0])
        let latest = BodyEntry(recordedAt: Date(), metrics: ["weight": 70.0])
        entryStore.addEntry(start)
        entryStore.addEntry(latest)
        let change = entryStore.totalChange(for: .weight)
        XCTAssertEqual(change ?? 0, -5.0, accuracy: 0.01)
    }

    @MainActor func testEmptyStoreQueries() {
        XCTAssertNil(entryStore.latestValue(for: .weight))
        XCTAssertNil(entryStore.totalChange(for: .weight))
        XCTAssertEqual(entryStore.currentStreak, 0)
        XCTAssertEqual(entryStore.totalRecordDays, 0)
    }

    @MainActor func testCurrentStreak() {
        // 3 consecutive days
        for i in 0..<3 {
            let entry = BodyEntry(
                recordedAt: Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date(),
                metrics: ["weight": 70.0]
            )
            entryStore.entries.append(entry)
        }
        XCTAssertEqual(entryStore.currentStreak, 3)
    }

    @MainActor func testRecentValues() {
        for i in 0..<10 {
            let entry = BodyEntry(
                recordedAt: Date().addingTimeInterval(Double(-i * 86400)),
                metrics: ["weight": Double(70 - i)]
            )
            entryStore.entries.append(entry)
        }
        let recent = entryStore.recentValues(for: .weight, limit: 5)
        XCTAssertLessThanOrEqual(recent.count, 5)
    }

    // MARK: - GoalModel Tests

    @MainActor func testGoalProgress_decrease() {
        let goal = GoalModel(metricType: .weight, targetValue: 65.0, direction: .decrease)
        // Start 75, current 70 → 50%
        let progress = goal.progress(currentValue: 70.0, startValue: 75.0)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    @MainActor func testGoalProgress_increase() {
        let goal = GoalModel(metricType: .muscleMass, targetValue: 50.0, direction: .increase)
        // Start 40, current 45 → 50%
        let progress = goal.progress(currentValue: 45.0, startValue: 40.0)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    @MainActor func testGoalIsReached() {
        let goal = GoalModel(metricType: .weight, targetValue: 65.0, direction: .decrease)
        XCTAssertTrue(goal.isReached(currentValue: 64.9))
        XCTAssertFalse(goal.isReached(currentValue: 65.1))
    }

    // MARK: - GoalStore Tests

    @MainActor func testGoalStoreCRUD() {
        let goal = GoalModel(metricType: .weight, targetValue: 65.0, direction: .decrease)
        goalStore.addGoal(goal)
        XCTAssertEqual(goalStore.activeGoals.count, 1)
        goalStore.markAchieved(id: goal.id)
        XCTAssertEqual(goalStore.achievedGoals.count, 1)
        XCTAssertEqual(goalStore.activeGoals.count, 0)
        goalStore.deleteGoal(id: goal.id)
        XCTAssertEqual(goalStore.goals.count, 0)
    }

    // MARK: - CSV Export Test

    @MainActor func testCSVExport() {
        let entry = BodyEntry(metrics: ["weight": 70.0, "bodyFat": 20.0], note: "test")
        entryStore.addEntry(entry)
        let csv = entryStore.exportCSV()
        XCTAssertTrue(csv.contains("70.00"))
        XCTAssertTrue(csv.contains("20.00"))
        XCTAssertTrue(csv.contains("test"))
    }

    // MARK: - BodyMetricType Tests

    @MainActor func testMetricTypeUnits() {
        XCTAssertEqual(BodyMetricType.weight.unit, "kg")
        XCTAssertEqual(BodyMetricType.bodyFat.unit, "%")
        XCTAssertEqual(BodyMetricType.waist.unit, "cm")
        XCTAssertEqual(BodyMetricType.bmi.unit, "")
    }

    @MainActor func testMetricTypeValidRanges() {
        XCTAssertTrue(BodyMetricType.weight.validRange.contains(70))
        XCTAssertFalse(BodyMetricType.weight.validRange.contains(10))
        XCTAssertTrue(BodyMetricType.bodyFat.validRange.contains(20))
    }

    // MARK: - Performance Test

    @MainActor func testPerformance100Entries() {
        for i in 0..<100 {
            let entry = BodyEntry(
                recordedAt: Date().addingTimeInterval(Double(-i * 3600)),
                metrics: ["weight": Double(65 + i % 10), "bodyFat": Double(20 + i % 5)]
            )
            entryStore.entries.append(entry)
        }

        measure {
            _ = entryStore.latestValue(for: .weight)
            _ = entryStore.totalChange(for: .weight)
            _ = entryStore.currentStreak
            _ = entryStore.recentValues(for: .weight, limit: 30)
        }
    }
}
