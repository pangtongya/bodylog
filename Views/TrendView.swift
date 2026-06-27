// TrendView.swift
// BodyLog — Premium Trend / Chart Screen
// Apple HIG-style immersive data-forward experience

import SwiftUI
import Charts

struct TrendView: View {

    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore

    // MARK: - State

    @State private var selectedMetric: BodyMetricType = .weight
    @State private var timeRange: TimeRange = .month3

    @State private var cachedDisplayData: [(date: Date, value: Double)] = []
    @State private var cachedStats: (latest: Double?, first: Double?, change: Double?, changePercent: Double?) = (nil, nil, nil, nil)
    @State private var cachedInsights: [(id: String, icon: String, text: String, subtitle: String?, color: Color)] = []
    @State private var cachedGoalTarget: Double? = nil
    @State private var cachedGoalProgress: Double? = nil

    // MARK: - TimeRange

    enum TimeRange: String, CaseIterable {
        case month1 = "1月"
        case month3 = "3月"
        case month6 = "6月"
        case all    = "全部"

        var localizedName: String {
            L10n.string(rawValue)
        }

        var days: Int? {
            switch self {
            case .month1: return 30
            case .month3: return 90
            case .month6: return 180
            case .all:    return nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 1 — Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // 2 — Metric selector pills
                    metricPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    if !cachedDisplayData.isEmpty {
                        // 3 — Big current value + change badge
                        currentValueSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // 4 — Stats 2x2 grid
                        statsGrid
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // 5 — Hero chart
                        chartCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // 6 — Time range picker
                        timeRangePicker
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // 7 — Insights
                        if !cachedInsights.isEmpty {
                            insightsCard
                                .padding(.horizontal, 20)
                                .padding(.bottom, 32)
                        }
                    } else {
                        emptyState
                            .padding(.horizontal, 20)
                            .padding(.top, 40)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.formlogBgGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
        .onAppear { recomputeChartData() }
        .onChange(of: selectedMetric) { _ in recomputeChartData() }
        .onChange(of: timeRange) { _ in recomputeChartData() }
        .onChange(of: entryStore.entries) { _ in recomputeChartData() }
        .onChange(of: appState.weightUnit) { _ in recomputeChartData() }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.string("趋势"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.formlogTextPrimary)
                .tracking(-0.5)
            Text(selectedMetric.displayName)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.formlogTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 2. Metric Picker

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.enabledMetrics) { metric in
                    Button(action: {
                        BodyLogHaptics.light()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedMetric = metric
                        }
                        // Auto-widen time range if insufficient data
                        if let days = timeRange.days {
                            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                            let count = entryStore.recentValues(for: metric, limit: Int.max).filter { $0.date >= cutoff }.count
                            if count < 2 {
                                withAnimation(.easeInOut(duration: 0.2)) { timeRange = .all }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(metric.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(selectedMetric == metric ? .white : .formlogTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            selectedMetric == metric
                                ? AnyShapeStyle(Color.formlogPrimary)
                                : AnyShapeStyle(Color.formlogCard)
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    selectedMetric == metric ? Color.clear : Color.formlogSeparator,
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: selectedMetric == metric ? Color.formlogPrimary.opacity(0.25) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            if let first = appState.enabledMetrics.first {
                selectedMetric = first
            }
        }
    }

    // MARK: - 3. Big Current Value

    private var currentValueSection: some View {
        let unitStr = displayUnit
        let (latest, _, change, _) = cachedStats

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let latest = latest {
                    Text(String(format: "%.1f", latest))
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.formlogTextPrimary)
                        .tracking(-1.5)
                        .monospacedDigit()
                        .id("value-\(latest)")
                        .contentTransition(.numericText())

                    Text(unitStr)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.formlogTextSecondary)
                        .padding(.bottom, 4)
                } else {
                    Text("--")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.formlogTextTertiary)
                }

                Spacer()

                // Change badge
                if let change = change {
                    let isGood = isGoodChange(change, for: selectedMetric)
                    let arrow = change >= 0 ? "arrow.up.right" : "arrow.down.right"
                    HStack(spacing: 4) {
                        Image(systemName: arrow)
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%@%.1f", change >= 0 ? "+" : "", abs(change)))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(isGood ? .formlogDecrease : .formlogDanger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill((isGood ? Color.formlogDecrease : Color.formlogDanger).opacity(0.12))
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentValueAccessibilityLabel)
    }

    private var statsGrid: some View {
        let unitStr = displayUnit
        let (_, first, change, _) = cachedStats

        let avg: Double? = {
            guard !cachedDisplayData.isEmpty else { return nil }
            let sum = cachedDisplayData.reduce(0) { $0 + $1.value }
            return sum / Double(cachedDisplayData.count)
        }()


        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statCard(
                    title: L10n.string("起始值"),
                    value: first.map { String(format: "%.1f", $0) } ?? "--",
                    unit: unitStr,
                    icon: "play.fill",
                    iconColor: .formlogBlue
                )
                statCard(
                    title: L10n.string("总变化"),
                    value: change.map { ($0 >= 0 ? "+" : "") + String(format: "%.1f", $0) } ?? "--",
                    unit: unitStr,
                    icon: "arrow.up.arrow.down",
                    iconColor: change != nil ? (isGoodChange(change ?? 0, for: selectedMetric) ? .formlogDecrease : .formlogDanger) : .formlogTextTertiary
                )
            }
            HStack(spacing: 10) {
                statCard(
                    title: L10n.string("平均值"),
                    value: avg.map { String(format: "%.1f", $0) } ?? "--",
                    unit: unitStr,
                    icon: "number",
                    iconColor: .formlogPurple
                )
                statCard(
                    title: L10n.string("记录次数"),
                    value: "\(cachedDisplayData.count)",
                    unit: L10n.string("次"),
                    icon: "list.bullet",
                    iconColor: .formlogOrange
                )
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.formlogTextPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.formlogTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 0.5)
        )
        .accessibilityLabel("\(title) \(value) \(unit)")
    }

    // MARK: - 5. Hero Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let goalTarget = cachedGoalTarget {
                goalLineHeader(target: goalTarget)
                    .padding(.bottom, 12)
            }

            Chart {
            ForEach(cachedDisplayData, id: \.date) { point in
                LineMark(
                    x: .value("date", point.date),
                    y: .value("value", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.formlogPrimary)

                AreaMark(
                    x: .value("date", point.date),
                    y: .value("value", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    .linearGradient(
                        colors: [
                            Color.formlogPrimary.opacity(0.25),
                            Color.formlogPrimary.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if let goalTarget = cachedGoalTarget {
                    RuleMark(y: .value("goal", goalTarget))
                        .foregroundStyle(Color.formlogPrimary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            goalAnnotation(target: goalTarget)
                        }
                }
            }
            }
            .chartXScale(domain: chartXDomain)
            .chartYScale(domain: chartYDomain)
            .frame(height: 240)
            .padding(16)
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(selectedMetric.displayName) \(L10n.string("趋势图表"))")
            .accessibilityValue(chartAccessibilityValue)
        }
    }

    private var chartXDomain: ClosedRange<Date> {
        guard let first = cachedDisplayData.first?.date,
              let last = cachedDisplayData.last?.date else {
            return Date()...Date()
        }
        return first...last
    }

    private var chartYDomain: ClosedRange<Double> {
        guard !cachedDisplayData.isEmpty else { return 0...100 }
        let values = cachedDisplayData.map(\.value)
        var minVal = values.min() ?? 0
        var maxVal = values.max() ?? 100

        // Include goal target in range
        if let goalTarget = cachedGoalTarget {
            minVal = min(minVal, goalTarget)
            maxVal = max(maxVal, goalTarget)
        }

        // Pad the range so data doesn't clip at edges
        let padding = max((maxVal - minVal) * 0.1, 1.0)
        return (minVal - padding)...(maxVal + padding)
    }

    private var displayUnit: String {
        (selectedMetric == .weight || selectedMetric == .muscleMass)
            ? appState.weightUnit.rawValue : selectedMetric.unit
    }

    // MARK: - Goal Line Components

    private func goalLineHeader(target: Double) -> some View {
        let unit = displayUnit
        let displayTarget = appState.displayWeight(target)
        let progress = cachedGoalProgress ?? 0

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("目标"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", selectedMetric == .weight || selectedMetric == .muscleMass ? displayTarget.value : target))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.formlogTextPrimary)
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundColor(.formlogTextSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(L10n.string("进度"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
                Text(String(format: "%.0f%%", min(progress * 100, 100)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(progress >= 1.0 ? .formlogDecrease : .formlogPrimary)
            }
        }
    }

    private func goalAnnotation(target: Double) -> some View {
        let unit = displayUnit
        let displayTarget = appState.displayWeight(target)

        return HStack(spacing: 4) {
            Image(systemName: "target")
                .font(.system(size: 10, weight: .semibold))
            Text(String(format: "%.1f%@", selectedMetric == .weight || selectedMetric == .muscleMass ? displayTarget.value : target, unit))
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundColor(.formlogPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.formlogPrimary.opacity(0.1))
        )
    }

    // MARK: - 6. Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    BodyLogHaptics.light()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        timeRange = range
                    }
                }) {
                    Text(range.localizedName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(timeRange == range ? .white : .formlogTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            timeRange == range
                                ? AnyShapeStyle(Color.formlogPrimary)
                                : AnyShapeStyle(Color.formlogCard)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    timeRange == range ? Color.clear : Color.formlogSeparator,
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(range.localizedName) time range")
                .accessibilityValue(timeRange == range ? "Selected" : "Not selected")
                .accessibilityAddTraits(timeRange == range ? .isSelected : [])
            }
        }
    }

    // MARK: - 7. Insights Card

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.formlogOrange)
                Text(L10n.string("数据洞察"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.formlogTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }

            VStack(spacing: 0) {
                ForEach(Array(cachedInsights.enumerated()), id: \.element.id) { index, insight in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(insight.color.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: insight.icon)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(insight.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.formlogTextPrimary)
                            if let subtitle = insight.subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.formlogTextSecondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if index < cachedInsights.count - 1 {
                        Rectangle()
                            .fill(Color.formlogSeparator)
                            .frame(height: 0.5)
                            .padding(.leading, 70)
                    }
                }
            }
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.08))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.04))
                    .frame(width: 120, height: 120)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.formlogPrimary.opacity(0.7))
            }

            VStack(spacing: 8) {
                Text(String(format: L10n.string("还没有%@的记录"), selectedMetric.displayName))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.formlogTextPrimary)
                Text(L10n.string("开始记录你的身体数据\n用图表见证你的变化"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.formlogTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }

            Button(action: {
                NotificationCenter.default.post(name: .init("SwitchToHomeTab"), object: nil)
            }) {
                Label(L10n.string("去记录"), systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.formlogPrimary)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Data Computation

    private func recomputeChartData() {
        let all = entryStore.recentValues(for: selectedMetric, limit: Int.max)
        let chart: [(date: Date, value: Double)] = {
            guard let days = timeRange.days else { return all }
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return all.filter { $0.date >= cutoff }
        }()

        // Apply unit conversion for display
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            cachedDisplayData = chart.map { point in
                let display = appState.displayWeight(point.value)
                return (date: point.date, value: display.value)
            }
        } else {
            cachedDisplayData = chart
        }

        let latest = cachedDisplayData.last?.value
        let first = cachedDisplayData.first?.value
        let change: Double? = {
            guard let l = latest, let f = first else { return nil }
            return l - f
        }()
        let changePercent: Double? = {
            guard let l = latest, let f = first, f != 0 else { return nil }
            return (l - f) / abs(f) * 100
        }()

        cachedStats = (latest, first, change, changePercent)
        cachedInsights = computeInsights()
        computeGoalData()
    }

    private func computeGoalData() {
        guard let goal = goalStore.activeGoal(for: selectedMetric) else {
            cachedGoalTarget = nil
            cachedGoalProgress = nil
            return
        }

        let targetValue: Double
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            switch appState.weightUnit {
            case .kg:  targetValue = goal.targetValue
            case .lb:  targetValue = goal.targetValue * 2.20462
            }
        } else {
            targetValue = goal.targetValue
        }

        cachedGoalTarget = targetValue

        if let current = entryStore.latestValue(for: goal.metricType) {
            let currentValue: Double
            if selectedMetric == .weight || selectedMetric == .muscleMass {
                switch appState.weightUnit {
                case .kg:  currentValue = current
                case .lb:  currentValue = current * 2.20462
                }
            } else {
                currentValue = current
            }

            let startValue = entryStore.startValue(for: goal.metricType) ?? current
            let startValueDisplay: Double
            if selectedMetric == .weight || selectedMetric == .muscleMass {
                switch appState.weightUnit {
                case .kg:  startValueDisplay = startValue
                case .lb:  startValueDisplay = startValue * 2.20462
                }
            } else {
                startValueDisplay = startValue
            }

            cachedGoalProgress = goal.progress(currentValue: currentValue, startValue: startValueDisplay)
        } else {
            cachedGoalProgress = nil
        }
    }

    private func computeInsights() -> [(id: String, icon: String, text: String, subtitle: String?, color: Color)] {
        var result: [(id: String, icon: String, text: String, subtitle: String?, color: Color)] = []

        // Insight 1: 30-day change
        if let change30d = entryStore.change30Days(for: selectedMetric) {
            let displayChange = (selectedMetric == .weight || selectedMetric == .muscleMass)
                ? appState.displayWeight(abs(change30d)).value
                : abs(change30d)
            let sign = change30d >= 0 ? "+" : ""
            let unit = (selectedMetric == .weight || selectedMetric == .muscleMass) ? appState.weightUnit.rawValue : selectedMetric.unit

            let (text, subtitle, color): (String, String?, Color) = if change30d > 0 {
                (String(format: L10n.string("30天增长了%@%.1f%@"), sign, displayChange, unit), L10n.string("继续保持，进步明显"), .formlogDanger)
            } else if change30d < 0 {
                (String(format: L10n.string("30天减少了%@%.1f%@"), sign, displayChange, unit), L10n.string("做得好，继续坚持"), .formlogDecrease)
            } else {
                (L10n.string("30天无变化"), L10n.string("保持现状也很重要"), .formlogTextSecondary)
            }

            result.append((id: "insight_30d", icon: "calendar.badge.clock", text: text, subtitle: subtitle, color: color))
        }

        // Insight 2: Streak
        let streak = entryStore.currentStreak
        if streak > 0 {
            let (text, subtitle, color): (String, String?, Color) = if streak >= 7 {
                (String(format: L10n.string("已连续记录%d天"), streak), L10n.string("习惯正在养成，太棒了"), .formlogOrange)
            } else if streak >= 3 {
                (String(format: L10n.string("已连续记录%d天"), streak), L10n.string("继续保持这个节奏"), .formlogPrimary)
            } else {
                (String(format: L10n.string("已连续记录%d天"), streak), L10n.string("好的开始"), .formlogPrimary)
            }
            result.append((id: "insight_streak", icon: "flame.fill", text: text, subtitle: subtitle, color: color))
        } else if let lastEntry = entryStore.latestEntry {
            let days = Calendar.current.dateComponents([.day], from: lastEntry.recordedAt, to: Date()).day ?? 0
            result.append((id: "insight_streak", icon: "flame", text: String(format: L10n.string("已%d天没有记录"), days), subtitle: L10n.string("别忘了记录今天的身体数据哦 😊"), color: .formlogTextSecondary))
        }

        // Insight 3: Goal progress
        if let goal = goalStore.activeGoal(for: selectedMetric), let current = entryStore.latestValue(for: goal.metricType) {
            let remainingKg = abs(goal.targetValue - current)
            let displayRemaining = (selectedMetric == .weight || selectedMetric == .muscleMass)
                ? appState.displayWeight(remainingKg).value
                : remainingKg
            let unit = (selectedMetric == .weight || selectedMetric == .muscleMass) ? appState.weightUnit.rawValue : selectedMetric.unit
            let progress = goal.progress(currentValue: current, startValue: entryStore.startValue(for: goal.metricType) ?? current)

            let (text, subtitle, color): (String, String?, Color) = if progress >= 1.0 {
                (L10n.string("目标已达成"), L10n.string("恭喜你，继续保持良好的状态"), .formlogDecrease)
            } else if progress >= 0.8 {
                (String(format: L10n.string("距离目标还差%.1f%@"), displayRemaining, unit), L10n.string("马上就要达成了，加油！"), .formlogPrimary)
            } else {
                (String(format: L10n.string("距离目标还差%.1f%@"), displayRemaining, unit), L10n.string("一步一步来，你可以的"), .formlogPrimary)
            }

            result.append((id: "insight_goal", icon: "target", text: text, subtitle: subtitle, color: color))
        }

        return Array(result.prefix(3))
    }

    // MARK: - Helpers

    private var chartAccessibilityValue: String {
        let (latest, _, change, _) = cachedStats
        guard let latest = latest else { return L10n.string("无数据") }
        var result = "\(L10n.string("当前")) \(String(format: "%.1f", latest)) \(displayUnit)"
        if let change = change {
            let direction = change >= 0 ? L10n.string("上升") : L10n.string("下降")
            result += "，\(direction) \(String(format: "%.1f", abs(change))) \(displayUnit)"
        }
        return result
    }

    private var currentValueAccessibilityLabel: String {
        let (latest, _, change, _) = cachedStats
        guard let latest = latest else { return L10n.string("无数据") }
        var result = "\(selectedMetric.displayName) \(String(format: "%.1f", latest)) \(displayUnit)"
        if let change = change {
            result += change >= 0 ? "，\(L10n.string("上升"))" : "，\(L10n.string("下降"))"
            result += " \(String(format: "%.1f", abs(change))) \(displayUnit)"
        }
        return result
    }

    private func isGoodChange(_ change: Double, for metric: BodyMetricType) -> Bool {
        switch metric {
        case .weight, .bodyFat, .bmi:
            return change < 0
        case .muscleMass:
            return change > 0
        case .waist, .hip, .chest, .leftArm, .rightArm, .leftThigh, .rightThigh, .neck:
            return change < 0
        }
    }
}

// MARK: - Preview

#Preview {
    TrendView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
