// WeeklyReportView.swift
// 周报视图 — Premium Apple HIG weekly body log report

import SwiftUI

struct WeeklyReportView: View {
    // MARK: - Dependencies

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - Static Formatters

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    // MARK: - State

    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    // MARK: - Inputs

    let weekStartDate: Date
    let weekEndDate: Date

    init(weekStartDate: Date = Date()) {
        self.weekStartDate = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        self.weekEndDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? Date()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .spacing2Xl) {
                    // 1. Record count card
                    recordCountCard

                    // 2. Weight change section
                    weightStatsCard

                    // 3. Mini chart
                    miniChartCard

                    // 4. Insights card
                    insightsCard

                    // 5. Share button
                    shareButton
                        .padding(.top, .spacingSm)
                }
                .padding(.horizontal, .spacingLg)
                .padding(.vertical, .spacingLg)
            }
            .background(Color.formlogBgGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .blNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.formlogPrimary)
                            Text(L10n.string("返回"))
                                .font(.blBodyMedium)
                                .foregroundColor(Color.formlogPrimary)
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(L10n.string("周报"))
                        .font(.blTitle3Semibold)
                        .foregroundColor(Color.formlogTextPrimary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Data Queries

    private var weekEntries: [BodyEntry] {
        entryStore.entries.filter { entry in
            entry.recordedAt >= weekStartDate && entry.recordedAt <= weekEndDate
        }.sorted { $0.recordedAt < $1.recordedAt }
    }

    private var recordDays: Int {
        let calendar = Calendar.current
        var days = Set<String>()
        for entry in weekEntries {
            let day = calendar.startOfDay(for: entry.recordedAt)
            days.insert(Self.iso8601Formatter.string(from: day))
        }
        return days.count
    }

    private var weekAverageWeight: Double? {
        let weights = weekEntries.compactMap { $0.value(for: .weight) }
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }

    private var weekMinWeight: Double? {
        let weights = weekEntries.compactMap { $0.value(for: .weight) }
        guard !weights.isEmpty else { return nil }
        return weights.min()
    }

    private var weekMaxWeight: Double? {
        let weights = weekEntries.compactMap { $0.value(for: .weight) }
        guard !weights.isEmpty else { return nil }
        return weights.max()
    }

    private var weekWeightChange: Double? {
        guard let first = weekEntries.first?.value(for: .weight),
              let last = weekEntries.last?.value(for: .weight) else { return nil }
        return last - first
    }

    // MARK: - Formatted Helpers

    private var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: weekStartDate)) — \(formatter.string(from: weekEndDate))"
    }

    private func formattedWeight(_ value: Double) -> String {
        let display = appState.displayWeight(value)
        return String(format: "%.1f", display.value) + display.unit
    }

    private var weightTrendIcon: String {
        guard let change = weekWeightChange else { return "minus" }
        if change < -0.01 { return "arrow.down.right" }
        if change > 0.01 { return "arrow.up.right" }
        return "arrow.right"
    }

    private var weightTrendColor: Color {
        guard let change = weekWeightChange else { return .formlogTextSecondary }
        if change < -0.01 { return .formlogDecrease }
        if change > 0.01 { return .formlogDanger }
        return .formlogTextSecondary
    }

    private var insightMessage: String {
        var parts: [String] = []

        let streak = entryStore.currentStreak
        if streak >= 7 {
            parts.append(String(format: L10n.string("🔥 已连续记录%d天！太棒了！"), streak))
        } else if streak >= 3 {
            parts.append(String(format: L10n.string("💪 已连续记录%d天，继续保持！"), streak))
        } else if streak > 0 {
            parts.append(L10n.string("👍 开始养成习惯了！"))
        }

        if let change = weekWeightChange {
            if change < 0 {
                let display = appState.displayWeight(abs(change))
                let v = String(format: "%.1f", display.value)
                parts.append(String(format: L10n.string("这周减了%@%@，继续加油！💪"), v, display.unit))
            } else if change > 0 {
                let display = appState.displayWeight(change)
                let v = String(format: "%.1f", display.value)
                parts.append(String(format: L10n.string("这周体重增加了%@%@，注意饮食哦"), v, display.unit))
            } else {
                parts.append(L10n.string("体重保持稳定，状态不错！"))
            }
        } else {
            parts.append(L10n.string("记录每一天，见证每一步改变 ✨"))
        }

        if weekEntries.contains(where: { $0.hasPhoto }) {
            parts.append(L10n.string("这周留下了珍贵的照片 ✨"))
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - 1. Record Count Card

    private var recordCountCard: some View {
        VStack(spacing: .spacingMd) {
            // Date range
            Text(weekRangeString)
                .font(.blFootnote)
                .foregroundColor(Color.formlogTextSecondary)

            // Hero number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(recordDays)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color.formlogPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)

                VStack(alignment: .leading, spacing: 2) {
                    Text("/ 7")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(Color.formlogTextQuaternary)
                    Text(L10n.string("本周记录"))
                        .font(.blFootnote)
                        .foregroundColor(Color.formlogTextSecondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                let progress = CGFloat(recordDays) / 7.0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: .radiusFull)
                        .fill(Color.formlogFillTertiary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: .radiusFull)
                        .fill(Color.formlogPrimary)
                        .frame(width: max(0, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, .spacingXl)
        .padding(.vertical, .spacing3Xl)
        .frame(maxWidth: .infinity)
        .blCard()
    }

    // MARK: - 2. Weight Stats Card

    private var weightStatsCard: some View {
        VStack(spacing: 0) {
            // Section label
            HStack(spacing: 6) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.formlogPrimary)
                Text(L10n.string("体重统计"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(Color.formlogTextPrimary)
                Spacer()
            }
            .padding(.horizontal, .spacingLg)
            .padding(.top, .spacingLg)
            .padding(.bottom, .spacingSm)

            // Average weight row
            if let avg = weekAverageWeight {
                statRow(
                    label: L10n.string("平均体重"),
                    value: formattedWeight(avg),
                    icon: "eq.3",
                    color: .formlogPrimary
                )
            }

            // Min weight row
            if let min = weekMinWeight {
                separatorInset
                statRow(
                    label: L10n.string("最低体重"),
                    value: formattedWeight(min),
                    icon: "arrow.down.to.line",
                    color: .formlogDecrease
                )
            }

            // Max weight row
            if let max = weekMaxWeight {
                separatorInset
                statRow(
                    label: L10n.string("最高体重"),
                    value: formattedWeight(max),
                    icon: "arrow.up.to.line",
                    color: .formlogDanger
                )
            }

            // Trend row
            if let change = weekWeightChange {
                separatorInset
                HStack(spacing: .spacingMd) {
                    Image(systemName: weightTrendIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(weightTrendColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(weightTrendColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("本周变化"))
                            .font(.blCaption1)
                            .foregroundColor(Color.formlogTextSecondary)
                        Text(formattedWeight(change))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(weightTrendColor)
                            .monospacedDigit()
                    }

                    Spacer()
                }
                .padding(.horizontal, .spacingLg)
                .padding(.vertical, 14)
            }

            // Goal distance row
            if let goal = goalStore.activeGoal(for: .weight),
               let current = entryStore.latestValue(for: .weight) {
                separatorInset
                let remaining = abs(goal.targetValue - current)
                statRow(
                    label: L10n.string("距离目标"),
                    value: formattedWeight(remaining),
                    icon: "target",
                    color: .formlogOrange
                )
            }

            // Bottom padding
            Spacer()
                .frame(height: .spacingSm)
        }
        .blCard()
    }

    private func statRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: .spacingMd) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.blCaption1)
                    .foregroundColor(Color.formlogTextSecondary)
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.formlogTextPrimary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(.horizontal, .spacingLg)
        .padding(.vertical, 14)
    }

    private var separatorInset: some View {
        Divider()
            .foregroundColor(Color.formlogSeparator)
            .padding(.leading, .spacingLg + 32 + .spacingMd)
            .padding(.trailing, .spacingLg)
    }

    // MARK: - 3. Mini Chart Card

    private var miniChartCard: some View {
        VStack(alignment: .leading, spacing: .spacingMd) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.flattrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.formlogBlue)
                Text(L10n.string("本周趋势"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(Color.formlogTextPrimary)
                Spacer()
            }

            if weekEntries.count >= 2 {
                miniChartBody
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
            } else {
                VStack(spacing: .spacingSm) {
                    Image(systemName: "chart.line.flattrend.xyaxis")
                        .font(.system(size: 28))
                        .foregroundColor(Color.formlogTextQuaternary)
                    Text(L10n.string("需要至少2条记录才能显示趋势"))
                        .font(.blCaption1)
                        .foregroundColor(Color.formlogTextTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.formlogFillTertiary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
            }
        }
        .padding(.horizontal, .spacingLg)
        .padding(.vertical, .spacingLg)
        .blCard()
    }

    private var miniChartBody: some View {
        let weights = weekEntries.compactMap { $0.value(for: .weight) }
        return Canvas { context, size in
            guard let minW = weights.min(), let maxW = weights.max(), maxW > minW else { return }
            let range = maxW - minW
            let padding: CGFloat = 8
            let drawWidth = size.width - padding * 2
            let drawHeight = size.height - padding * 2

            // Fill gradient path
            var fillPath = Path()
            for (index, weight) in weights.enumerated() {
                let x = weights.count == 1
                    ? size.width / 2
                    : padding + (CGFloat(index) / CGFloat(max(weights.count - 1, 1))) * drawWidth
                let y = padding + drawHeight - ((weight - minW) / range) * drawHeight
                if index == 0 { fillPath.move(to: CGPoint(x: x, y: y)) }
                else { fillPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            fillPath.addLine(to: CGPoint(x: padding + drawWidth, y: size.height - padding))
            fillPath.addLine(to: CGPoint(x: padding, y: size.height - padding))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.formlogPrimary.opacity(0.2), location: 0),
                        .init(color: Color.formlogPrimary.opacity(0.02), location: 1)
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )

            // Stroke line
            var linePath = Path()
            for (index, weight) in weights.enumerated() {
                let x = weights.count == 1
                    ? size.width / 2
                    : padding + (CGFloat(index) / CGFloat(max(weights.count - 1, 1))) * drawWidth
                let y = padding + drawHeight - ((weight - minW) / range) * drawHeight
                if index == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
                else { linePath.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(
                linePath,
                with: .color(Color.formlogPrimary),
                lineWidth: 2
            )

            // Dots
            for (index, weight) in weights.enumerated() {
                let x = weights.count == 1
                    ? size.width / 2
                    : padding + (CGFloat(index) / CGFloat(max(weights.count - 1, 1))) * drawWidth
                let y = padding + drawHeight - ((weight - minW) / range) * drawHeight
                let outerDot = Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                let innerDot = Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                context.fill(outerDot, with: .color(Color.formlogPrimary))
                context.fill(innerDot, with: .color(Color.formlogCard))
            }
        }
    }

    // MARK: - 4. Insights Card

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: .spacingMd) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.formlogOrange)
                Text(L10n.string("本周洞察"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(Color.formlogTextPrimary)
                Spacer()
            }

            Text(insightMessage)
                .font(.blBody)
                .foregroundColor(Color.formlogTextPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, .spacingLg)
        .padding(.vertical, .spacingLg)
        .blCard()
    }

    // MARK: - 5. Share Button

    private var shareButton: some View {
        Button {
            BodyLogHaptics.medium()
            shareReport()
        } label: {
            HStack(spacing: .spacingSm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text(L10n.string("分享周报"))
                    .font(.blBodySemibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.formlogPrimary)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        }
    }

    // MARK: - Actions

    private func shareReport() {
        AchievementManager.shared.markShared()

        var shareText = L10n.string("周报标题") + "\n"
        shareText += "\(weekRangeString)\n\n"
        shareText += String(format: L10n.string("周报记录天数"), recordDays) + "\n"
        shareText += String(format: L10n.string("周报记录次数"), weekEntries.count) + "\n"

        if let avg = weekAverageWeight {
            let display = appState.displayWeight(avg)
            shareText += String(format: L10n.string("周报平均体重"), String(format: "%.1f", display.value), display.unit) + "\n"
        }

        if let change = weekWeightChange {
            let display = appState.displayWeight(abs(change))
            let sign = change >= 0 ? "+" : ""
            shareText += String(format: L10n.string("周报体重变化"), sign, String(format: "%.1f", display.value), display.unit) + "\n"
        }

        shareText += "\n\(streakMessage)\n"
        shareText += L10n.string("分享结尾")

        shareItems = [shareText]
        showShareSheet = true
    }

    private var streakMessage: String {
        let streak = entryStore.currentStreak
        if streak >= 7 {
            return String(format: L10n.string("🔥 已连续记录%d天！太棒了！"), streak)
        } else if streak >= 3 {
            return String(format: L10n.string("💪 已连续记录%d天，继续保持！"), streak)
        } else if streak > 0 {
            return L10n.string("👍 开始养成习惯了！")
        } else {
            return String(format: L10n.string("📝 本周记录了%d次"), weekEntries.count)
        }
    }
}

#Preview {
    WeeklyReportView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
