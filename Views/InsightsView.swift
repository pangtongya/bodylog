import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedPeriod: Period = .week
    @State private var selectedMetric: BodyMetricType = .weight

    enum Period: String, CaseIterable {
        case week = "week"
        case month = "month"
        case threeMonths = "threeMonths"
        case year = "year"

        var displayName: String {
            switch self {
            case .week: return L10n.string("本周")
            case .month: return L10n.string("本月")
            case .threeMonths: return L10n.string("近三月")
            case .year: return L10n.string("今年")
            }
        }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                        .padding(.horizontal, 20)

                    metricSelector
                        .padding(.horizontal, 20)

                    summaryCard
                        .padding(.horizontal, 20)

                    trendChartCard
                        .padding(.horizontal, 20)

                    insightsCard
                        .padding(.horizontal, 20)

                    goalProgressCard
                        .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle(L10n.string("数据洞察"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { period in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedPeriod = period
                }) {
                    Text(period.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .white : .secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            selectedPeriod == period
                                ? LinearGradient.formlogGradient
                                : Color.clear
                        )
                        .cornerRadius(10)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(4)
        .background(Color.systemGray6)
        .cornerRadius(12)
    }

    private var metricSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.enabledMetrics, id: \.self) { metric in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedMetric = metric
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 13))
                            Text(metric.displayName)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(selectedMetric == metric ? .white : .formlogPrimary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            selectedMetric == metric
                                ? LinearGradient.formlogGradient
                                : Color.formlogPrimary.opacity(0.1)
                        )
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.string("数据摘要"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(periodRangeText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            let stats = computeStats()

            HStack(spacing: 0) {
                statItem(title: L10n.string("起始值"), value: stats.startValue, unit: unitString)
                Divider().frame(height: 50)
                statItem(title: L10n.string("当前值"), value: stats.currentValue, unit: unitString)
                Divider().frame(height: 50)
                statItem(
                    title: L10n.string("变化"),
                    value: stats.change,
                    unit: unitString,
                    isChange: true,
                    isPositive: stats.change > 0
                )
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("记录天数"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("\(stats.recordDays)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.string("平均变化"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(String(format: "%+.2f %@/周", stats.avgWeeklyChange, unitString))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(stats.avgWeeklyChange > 0 ? .formlogDanger : .green)
                }
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
    }

    private func statItem(title: String, value: Double, unit: String, isChange: Bool = false, isPositive: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(isChange ? (value >= 0 ? "+" : "") + String(format: "%.1f", value) : String(format: "%.1f", value))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(isChange ? (isPositive ? .formlogDanger : .green) : .primary)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("趋势变化"))
                .font(.system(size: 16, weight: .semibold))

            let entries = periodEntries()

            if entries.count >= 2 {
                Chart {
                    ForEach(entries, id: \.recordedAt) { entry in
                        LineMark(
                            x: .value(L10n.string("日期"), entry.recordedAt, unit: .day),
                            y: .value(selectedMetric.displayName, value(for: entry))
                        )
                        .interpolationMethod(.cardinal)
                        .foregroundStyle(LinearGradient.formlogGradient)

                        PointMark(
                            x: .value(L10n.string("日期"), entry.recordedAt, unit: .day),
                            y: .value(selectedMetric.displayName, value(for: entry))
                        )
                        .foregroundStyle(Color.formlogPrimary)
                    }

                    if let goal = goalStore.goals.first(where: { $0.metricType == selectedMetric && $0.isActive }) {
                        RuleMark(
                            y: .value(L10n.string("目标"), goal.targetValue)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .stride(by: .day, count: strideCount)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.system(size: 10))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(L10n.string("数据不足，无法生成趋势图"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
    }

    private var strideCount: Int {
        switch selectedPeriod {
        case .week: return 1
        case .month: return 5
        case .threeMonths: return 15
        case .year: return 60
        }
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(L10n.string("智能洞察"))
                    .font(.system(size: 16, weight: .semibold))
            }

            let insights = generateInsights()

            if insights.isEmpty {
                Text(L10n.string("记录更多数据以获取智能洞察"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: insight.icon)
                                .font(.system(size: 14))
                                .foregroundColor(insight.color)
                                .padding(.top, 2)
                            Text(insight.text)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
    }

    private var goalProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundColor(.formlogPrimary)
                Text(L10n.string("目标进度"))
                    .font(.system(size: 16, weight: .semibold))
            }

            let activeGoals = goalStore.activeGoals

            if activeGoals.isEmpty {
                Text(L10n.string("暂无进行中的目标"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(activeGoals) { goal in
                        goalProgressRow(goal)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(16)
    }

    private func goalProgressRow(_ goal: GoalModel) -> some View {
        let currentValue = entryStore.latestValue(for: goal.metricType) ?? 0
        let progress = goal.progressPercentage(currentValue: currentValue)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: goal.metricType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.formlogPrimary)
                    Text(goal.metricType.displayName)
                        .font(.system(size: 14, weight: .medium))
                }
                Spacer()
                Text(String(format: "%.0f%%", progress))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(goal.isAchieved ? .green : .formlogPrimary)
            }

            ProgressView(value: min(progress / 100, 1.0))
                .tint(goal.isAchieved ? .green : .formlogPrimary)

            HStack {
                Text(String(format: L10n.string("当前：%.1f %@"), currentValue, goal.metricType.unit))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: L10n.string("目标：%.1f %@"), goal.targetValue, goal.metricType.unit))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var unitString: String {
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            return appState.weightUnit.rawValue
        }
        return selectedMetric.unit
    }

    private var periodRangeText: String {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now) ?? now

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: now))"
    }

    private func periodEntries() -> [BodyEntry] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now) ?? now

        return entryStore.entries
            .filter { $0.recordedAt >= startDate && $0.recordedAt <= now }
            .sorted(by: { $0.recordedAt < $1.recordedAt })
    }

    private func value(for entry: BodyEntry) -> Double {
        let val = entry.metrics[selectedMetric] ?? 0
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            return appState.weightUnit.convert(val, from: .kg)
        }
        return val
    }

    private func computeStats() -> (startValue: Double, currentValue: Double, change: Double, recordDays: Int, avgWeeklyChange: Double) {
        let entries = periodEntries()
        guard entries.count >= 1 else {
            return (0, 0, 0, 0, 0)
        }

        let first = value(for: entries.first!)
        let last = value(for: entries.last!)
        let change = last - first
        let days = entries.count

        let avgWeeklyChange = days > 1 ? change / Double(days - 1) * 7 : 0

        return (first, last, change, days, avgWeeklyChange)
    }

    private struct Insight: Hashable {
        let icon: String
        let text: String
        let color: Color
    }

    private func generateInsights() -> [Insight] {
        var insights: [Insight] = []
        let stats = computeStats()
        let entries = periodEntries()

        guard entries.count >= 3 else {
            return [Insight(
                icon: "chart.bar.doc.horizontal",
                text: L10n.string("继续记录更多数据，即可获取个性化洞察"),
                color: .secondary
            )]
        }

        let goal = goalStore.activeGoals.first(where: { $0.metricType == selectedMetric })

        if let goal = goal {
            let currentValue = entryStore.latestValue(for: selectedMetric) ?? 0
            let remaining = abs(goal.targetValue - currentValue)

            if goal.isAchieved {
                insights.append(Insight(
                    icon: "trophy.fill",
                    text: String(format: L10n.string("恭喜！你已达成「%@」目标 🎉"), selectedMetric.displayName),
                    color: .green
                ))
            } else {
                if stats.avgWeeklyChange != 0 {
                    let direction: GoalModel.GoalDirection = goal.goalDirection
                    let isOnTrack = (direction == .lose && stats.avgWeeklyChange < 0) ||
                                    (direction == .gain && stats.avgWeeklyChange > 0)

                    if isOnTrack {
                        let weeksToGoal = remaining / abs(stats.avgWeeklyChange)
                        if weeksToGoal > 0 && weeksToGoal < 52 {
                            insights.append(Insight(
                                icon: "flag.checkered",
                                text: String(format: L10n.string("照此速度，大约%.0f周后可达标"), weeksToGoal),
                                color: .green
                            ))
                        }
                    } else {
                        insights.append(Insight(
                            icon: "exclamationmark.triangle.fill",
                            text: L10n.string("当前趋势与目标方向相反，需要调整哦"),
                            color: .orange
                        ))
                    }
                }
            }
        }

        if stats.recordDays >= 5 {
            insights.append(Insight(
                icon: "flame.fill",
                text: String(format: L10n.string("本期记录了%d天，继续保持！"), stats.recordDays),
                color: .orange
            ))
        }

        if abs(stats.change) > 0 {
            let isLosing = stats.change < 0
            insights.append(Insight(
                icon: isLosing ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                text: String(format: L10n.string("本期%@了%.1f%@"), isLosing ? L10n.string("下降") : L10n.string("上升"), abs(stats.change), unitString),
                color: isLosing ? .green : .formlogDanger
            ))
        }

        return Array(insights.prefix(4))
    }
}

#Preview {
    InsightsView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore.shared)
        .environmentObject(GoalStore.shared)
}
