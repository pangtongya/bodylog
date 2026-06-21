// TrendView.swift
// 趋势图 + 全部历史

import SwiftUI
import Charts

struct TrendView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore

    @State private var selectedMetric: BodyMetricType = .weight
    @State private var timeRange: TimeRange = .month3

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
            case .all: return nil
            }
        }
    }

    private var chartData: [(date: Date, value: Double)] {
        let all = entryStore.recentValues(for: selectedMetric, limit: 500)
        guard let days = timeRange.days else { return all }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return all.filter { $0.date >= cutoff }
    }

    private var displayData: [(date: Date, value: Double)] {
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            return chartData.map { point in
                let kgVal = point.value
                let display = appState.displayWeight(kgVal)
                return (date: point.date, value: display.value)
            }
        }
        return chartData
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Metric selector
                    metricPicker
                        .padding(.horizontal, 20)

                    // Insights card
                    if !displayData.isEmpty {
                        insightsCard
                            .padding(.horizontal, 20)
                    }

                    // Summary stats
                    if !displayData.isEmpty {
                        statsSummary
                            .padding(.horizontal, 20)
                    }

                    // Chart
                    chartCard
                        .padding(.horizontal, 20)

                    // Time range
                    timeRangePicker
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("趋势")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.enabledMetrics) { metric in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedMetric = metric
                        // Reset time range if new metric has sparse data
                        if let days = timeRange.days {
                            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                            let count = entryStore.recentValues(for: metric, limit: 500).filter { $0.date >= cutoff }.count
                            if count < 2 {
                                withAnimation(.easeInOut(duration: 0.2)) { timeRange = .all }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 13))
                            Text(metric.displayName)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(selectedMetric == metric ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedMetric == metric ? Color.bodylogPrimary : Color.systemGray6)
                        .cornerRadius(20)
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .onAppear {
            // Default to first enabled metric
            if let first = appState.enabledMetrics.first {
                selectedMetric = first
            }
        }
    }

    // MARK: - Stats Summary
    
    private var statsSummary: some View {
        let latest = displayData.last?.value
        let first = displayData.first?.value
        let change = (latest != nil && first != nil) ? latest! - first! : nil
        let changePercent = (latest != nil && first != nil && first! != 0) ? (latest! - first!) / abs(first!) * 100 : nil
        let unitStr = (selectedMetric == .weight || selectedMetric == .muscleMass)
            ? appState.weightUnit.rawValue : selectedMetric.unit
        
        return VStack(spacing: 12) {
            // Title
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.bodylogPrimary)
                Text("数据概览")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            
            // Stats grid
            HStack(spacing: 0) {
                statCell(
                    icon: "circle.fill",
                    iconColor: .bodylogPrimary,
                    title: "当前值",
                    value: latest.map { String(format: "%.1f", $0) } ?? "--",
                    unit: unitStr,
                    trend: nil
                )
                
                Divider().frame(height: 50)
                
                statCell(
                    icon: "arrow.up.arrow.down",
                    iconColor: isGoodChange(change ?? 0, for: selectedMetric) ? .bodylogDecrease : .bodylogDanger,
                    title: "总变化",
                    value: change.map { ($0 >= 0 ? "+" : "") + String(format: "%.1f", $0) } ?? "--",
                    unit: unitStr,
                    trend: change.map { $0 >= 0 ? "up" : "down" }
                )
                
                Divider().frame(height: 50)
                
                statCell(
                    icon: "percent",
                    iconColor: isGoodChange(changePercent ?? 0, for: selectedMetric) ? .bodylogDecrease : .bodylogDanger,
                    title: "变化率",
                    value: changePercent.map { ($0 >= 0 ? "+" : "") + String(format: "%.1f", $0) } ?? "--",
                    unit: "%",
                    trend: changePercent.map { $0 >= 0 ? "up" : "down" }
                )
                
                Divider().frame(height: 50)
                
                statCell(
                    icon: "number",
                    iconColor: .purple,
                    title: "记录次数",
                    value: "\(displayData.count)",
                    unit: "次",
                    trend: nil
                )
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private func statCell(icon: String, iconColor: Color, title: String, value: String, unit: String, trend: String?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                if let trend = trend {
                    Image(systemName: trend == "up" ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(trend == "up" ? .bodylogDanger : .bodylogDecrease)
                }
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(iconColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insights Card
    
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("数据洞察")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(insight.color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: insight.icon)
                            .font(.system(size: 14))
                            .foregroundColor(insight.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        if let subtitle = insight.subtitle {
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                
                if index < insights.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private var insights: [(id: UUID, icon: String, text: String, subtitle: String?, color: Color)] {
        var result: [(id: UUID, icon: String, text: String, subtitle: String?, color: Color)] = []

        // Insight 1: Recent change (30 days)
        if let change30d = entryStore.change30Days(for: selectedMetric) {
            let absChange = abs(change30d)
            let sign = change30d >= 0 ? "+" : ""
            let unit = (selectedMetric == .weight || selectedMetric == .muscleMass) ? appState.weightUnit.rawValue : selectedMetric.unit

            let (text, subtitle, color): (String, String?, Color) = if change30d > 0 {
                (String(format: L10n.string("30天增长了%@%.1f%@"), sign, absChange, unit), L10n.string("继续保持，进步明显 💪"), .bodylogDanger)
            } else if change30d < 0 {
                (String(format: L10n.string("30天减少了%@%.1f%@"), sign, absChange, unit), L10n.string("做得好，继续坚持 🎯"), .bodylogDecrease)
            } else {
                (L10n.string("30天无变化"), L10n.string("保持现状也很重要 😊"), .secondary)
            }

            result.append((id: UUID(), icon: "calendar.badge.clock", text: text, subtitle: subtitle, color: color))
        }

        // Insight 2: Streak
        let streak = entryStore.currentStreak
        if streak > 0 {
            let (text, subtitle, color): (String, String?, Color) = if streak >= 7 {
                (String(format: L10n.string("已连续记录%d天"), streak), L10n.string("习惯正在养成，太棒了 🔥"), .orange)
            } else if streak >= 3 {
                (String(format: L10n.string("已连续记录%d天"), streak), L10n.string("继续保持这个节奏 👍"), .bodylogPrimary)
            } else {
                (String(format: L10n.string("已连续记录%d天"), streak), L10n.string("好的开始 💪"), .bodylogPrimary)
            }
            result.append((id: UUID(), icon: "flame.fill", text: text, subtitle: subtitle, color: color))
        } else if let lastEntry = entryStore.latestEntry {
            let days = Calendar.current.dateComponents([.day], from: lastEntry.recordedAt, to: Date()).day ?? 0
            result.append((id: UUID(), icon: "flame", text: String(format: L10n.string("已%d天没有记录"), days), subtitle: L10n.string("别忘了记录今天的身体数据哦 😊"), color: .secondary))
        }

        // Insight 3: Goal progress (if has active goal)
        if let goal = goalStore.activeGoal(for: selectedMetric), let current = entryStore.latestValue(for: goal.metricType) {
            let remaining = abs(goal.targetValue - current)
            let unit = (selectedMetric == .weight || selectedMetric == .muscleMass) ? appState.weightUnit.rawValue : selectedMetric.unit
            let progress = goal.progress(currentValue: current, startValue: entryStore.startValue(for: goal.metricType) ?? current)

            let (text, subtitle, color): (String, String?, Color) = if progress >= 1.0 {
                (L10n.string("目标已达成 🎉"), L10n.string("恭喜你，继续保持良好的状态"), .bodylogDecrease)
            } else if progress >= 0.8 {
                (String(format: L10n.string("距离目标还差%.1f%@"), remaining, unit), L10n.string("马上就要达成了，加油！💪"), .bodylogPrimary)
            } else {
                (String(format: L10n.string("距离目标还差%.1f%@"), remaining, unit), L10n.string("一步一步来，你可以的 ✨"), .bodylogPrimary)
            }

            result.append((id: UUID(), icon: "target", text: text, subtitle: subtitle, color: color))
        }

        return Array(result.prefix(3))
    }

    // MARK: - Chart
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if displayData.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.bodylogPrimary.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36))
                            .foregroundColor(.bodylogPrimary)
                    }
                    VStack(spacing: 6) {
                        Text("还没有\(selectedMetric.displayName)的记录")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("开始记录你的身体数据\n用图表见证你的变化 ✨")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else {
                Chart {
                    ForEach(displayData, id: \.date) { point in
                        // Area gradient
                        AreaMark(
                            x: .value("日期", point.date),
                            y: .value(selectedMetric.displayName, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.bodylogPrimary.opacity(0.35), .bodylogPrimary.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        // Line
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value(selectedMetric.displayName, point.value)
                        )
                        .foregroundStyle(Color.bodylogPrimary)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        // Points
                        PointMark(
                            x: .value("日期", point.date),
                            y: .value(selectedMetric.displayName, point.value)
                        )
                        .foregroundStyle(Color.bodylogPrimary)
                        .symbolSize(displayData.count > 30 ? 0 : 36)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(String(format: "%.1f", d))
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var yDomain: ClosedRange<Double> {
        guard !displayData.isEmpty else { return 0...100 }
        let values = displayData.map(\.value)
        let minVal = (values.min() ?? 0) - 2
        let maxVal = (values.max() ?? 100) + 2
        return minVal...maxVal
    }

    /// 变化对于该指标是否是"好的"（区分指标类型）
    private func isGoodChange(_ change: Double, for type: BodyMetricType) -> Bool {
        switch type {
        case .weight, .bodyFat, .waist, .hip: return change < 0  // 减少是好事
        case .muscleMass: return change > 0  // 增加是好事
        default: return false
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) { timeRange = range }
                }) {
                    Text(range.localizedName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(timeRange == range ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(timeRange == range ? Color.bodylogPrimary : Color.clear)
                        .cornerRadius(8)
                }
                .contentShape(Rectangle())
            }
        }
        .padding(4)
        .background(Color.systemGray6)
        .cornerRadius(12)
    }
}

#Preview {
    TrendView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
