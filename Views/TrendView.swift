// TrendView.swift
// 趋势图 + 全部历史

import SwiftUI
import Charts

struct TrendView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore

    @State private var selectedMetric: BodyMetricType = .weight
    @State private var timeRange: TimeRange = .month3

    enum TimeRange: String, CaseIterable {
        case month1 = "1月"
        case month3 = "3月"
        case month6 = "6月"
        case all    = "全部"

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
        let unitStr = (selectedMetric == .weight || selectedMetric == .muscleMass)
            ? appState.weightUnit.rawValue : selectedMetric.unit

        return HStack(spacing: 0) {
            summaryStatCell(
                title: "当前",
                value: latest.map { String(format: "%.1f", $0) } ?? "--",
                unit: unitStr,
                color: .bodylogPrimary
            )
            Divider().frame(height: 40)
            summaryStatCell(
                title: "最低",
                value: displayData.map(\.value).min().map { String(format: "%.1f", $0) } ?? "--",
                unit: unitStr,
                color: .bodylogDecrease
            )
            Divider().frame(height: 40)
            summaryStatCell(
                title: "变化",
                value: change.map { (($0 >= 0 ? "+" : "") + String(format: "%.1f", $0)) } ?? "--",
                unit: unitStr,
                color: (change ?? 0) < 0 ? .bodylogDecrease : .bodylogDanger
            )
            Divider().frame(height: 40)
            summaryStatCell(
                title: "记录",
                value: "\(displayData.count)",
                unit: "次",
                color: .secondary
            )
        }
        .padding(.vertical, 12)
        .background(Color.systemBackground)
        .cornerRadius(14)
    }

    private func summaryStatCell(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if displayData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 36))
                        .foregroundColor(.bodylogPrimary.opacity(0.4))
                    Text("还没有\(selectedMetric.displayName)的记录")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("在首页点击，点【记录】添加数据")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
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

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) { timeRange = range }
                }) {
                    Text(range.rawValue)
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
}
