// MonthlyReportView.swift
// Premium Apple HIG monthly body log report

import SwiftUI

struct MonthlyReportView: View {
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

    let monthDate: Date

    init(monthDate: Date = Date()) {
        self.monthDate = monthDate
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .spacing2Xl) {
                    // 1. Date range + record count card
                    recordCountCard

                    // 2. Weight section
                    weightStatsCard

                    // 3. Body fat section
                    bodyFatStatsCard

                    // 4. Mini chart
                    miniChartCard

                    // 5. Milestones card
                    milestonesCard

                    // 6. Share button
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
                    Text(L10n.string("月报"))
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

    private var calendar: Calendar { Calendar.current }

    private var monthStartDate: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
    }

    private var monthEndDate: Date {
        calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStartDate) ?? monthDate
    }

    private var monthEntries: [BodyEntry] {
        entryStore.entries.filter { entry in
            entry.recordedAt >= monthStartDate && entry.recordedAt <= monthEndDate
        }.sorted { $0.recordedAt < $1.recordedAt }
    }

    private var recordDays: Int {
        var days = Set<String>()
        for entry in monthEntries {
            let day = calendar.startOfDay(for: entry.recordedAt)
            days.insert(Self.iso8601Formatter.string(from: day))
        }
        return days.count
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
    }

    private var monthAverageWeight: Double? {
        let weights = monthEntries.compactMap { $0.value(for: .weight) }
        guard !weights.isEmpty else { return nil }
        return weights.reduce(0, +) / Double(weights.count)
    }

    private var monthWeightChange: Double? {
        guard let first = monthEntries.first?.value(for: .weight),
              let last = monthEntries.last?.value(for: .weight) else { return nil }
        return last - first
    }

    private var lowestWeight: Double? {
        monthEntries.compactMap { $0.value(for: .weight) }.min()
    }

    private var highestWeight: Double? {
        monthEntries.compactMap { $0.value(for: .weight) }.max()
    }

    private var monthAverageBodyFat: Double? {
        let values = monthEntries.compactMap { $0.value(for: .bodyFat) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var monthBodyFatChange: Double? {
        guard let first = monthEntries.first?.value(for: .bodyFat),
              let last = monthEntries.last?.value(for: .bodyFat) else { return nil }
        return last - first
    }

    private var lowestBodyFat: Double? {
        monthEntries.compactMap { $0.value(for: .bodyFat) }.min()
    }

    private var highestBodyFat: Double? {
        monthEntries.compactMap { $0.value(for: .bodyFat) }.max()
    }

    private var photoCount: Int {
        monthEntries.filter { $0.hasPhoto }.count
    }

    // MARK: - Formatted Helpers

    private var monthRangeString: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return "\(formatter.string(from: monthStartDate)) — \(formatter.string(from: monthEndDate))"
    }

    private func formattedWeight(_ value: Double) -> String {
        let display = appState.displayWeight(value)
        return String(format: "%.1f", display.value) + display.unit
    }

    private func formattedBodyFat(_ value: Double) -> String {
        return String(format: "%.1f", value) + "%"
    }

    private var weightTrendIcon: String {
        guard let change = monthWeightChange else { return "minus" }
        if change < -0.01 { return "arrow.down.right" }
        if change > 0.01 { return "arrow.up.right" }
        return "arrow.right"
    }

    private var weightTrendColor: Color {
        guard let change = monthWeightChange else { return .formlogTextSecondary }
        if change < -0.01 { return .formlogDecrease }
        if change > 0.01 { return .formlogDanger }
        return .formlogTextSecondary
    }

    private var bodyFatTrendIcon: String {
        guard let change = monthBodyFatChange else { return "minus" }
        if change < -0.01 { return "arrow.down.right" }
        if change > 0.01 { return "arrow.up.right" }
        return "arrow.right"
    }

    private var bodyFatTrendColor: Color {
        guard let change = monthBodyFatChange else { return .formlogTextSecondary }
        if change < -0.01 { return .formlogDecrease }
        if change > 0.01 { return .formlogDanger }
        return .formlogTextSecondary
    }

    // MARK: - 1. Record Count Card

    private var recordCountCard: some View {
        VStack(spacing: .spacingMd) {
            // Date range
            Text(monthRangeString)
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
                    Text("/ \(daysInMonth)")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(Color.formlogTextQuaternary)
                    Text(L10n.string("本月记录"))
                        .font(.blFootnote)
                        .foregroundColor(Color.formlogTextSecondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                let progress = CGFloat(recordDays) / CGFloat(daysInMonth)
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

            // Average weight
            if let avg = monthAverageWeight {
                statRow(
                    label: L10n.string("平均体重"),
                    value: formattedWeight(avg),
                    icon: "eq.3",
                    color: .formlogPrimary
                )
            }

            // Min weight
            if let min = lowestWeight {
                separatorInset
                statRow(
                    label: L10n.string("最低体重"),
                    value: formattedWeight(min),
                    icon: "arrow.down.to.line",
                    color: .formlogDecrease
                )
            }

            // Max weight
            if let max = highestWeight {
                separatorInset
                statRow(
                    label: L10n.string("最高体重"),
                    value: formattedWeight(max),
                    icon: "arrow.up.to.line",
                    color: .formlogDanger
                )
            }

            // Monthly change
            if let change = monthWeightChange {
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
                        Text(L10n.string("本月变化"))
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

            // Goal distance
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

            Spacer()
                .frame(height: .spacingSm)
        }
        .blCard()
    }

    // MARK: - 3. Body Fat Stats Card

    private var bodyFatStatsCard: some View {
        let hasBodyFat = monthAverageBodyFat != nil
            || lowestBodyFat != nil
            || highestBodyFat != nil
            || monthBodyFatChange != nil

        if !hasBodyFat {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(spacing: 0) {
                // Section label
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.formlogBodyFat)
                    Text(L10n.string("体脂率统计"))
                        .font(.blSubheadSemibold)
                        .foregroundColor(Color.formlogTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, .spacingLg)
                .padding(.top, .spacingLg)
                .padding(.bottom, .spacingSm)

                // Average body fat
                if let avg = monthAverageBodyFat {
                    statRow(
                        label: L10n.string("平均体脂率"),
                        value: formattedBodyFat(avg),
                        icon: "eq.3",
                        color: .formlogBodyFat
                    )
                }

                // Min body fat
                if let min = lowestBodyFat {
                    separatorInset
                    statRow(
                        label: L10n.string("最低体脂率"),
                        value: formattedBodyFat(min),
                        icon: "arrow.down.to.line",
                        color: .formlogDecrease
                    )
                }

                // Max body fat
                if let max = highestBodyFat {
                    separatorInset
                    statRow(
                        label: L10n.string("最高体脂率"),
                        value: formattedBodyFat(max),
                        icon: "arrow.up.to.line",
                        color: .formlogDanger
                    )
                }

                // Monthly change
                if let change = monthBodyFatChange {
                    separatorInset
                    HStack(spacing: .spacingMd) {
                        Image(systemName: bodyFatTrendIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(bodyFatTrendColor)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bodyFatTrendColor.opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.string("本月变化"))
                                .font(.blCaption1)
                                .foregroundColor(Color.formlogTextSecondary)
                            Text(formattedBodyFat(change))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(bodyFatTrendColor)
                                .monospacedDigit()
                        }

                        Spacer()
                    }
                    .padding(.horizontal, .spacingLg)
                    .padding(.vertical, 14)
                }

                Spacer()
                    .frame(height: .spacingSm)
            }
            .blCard()
        )
    }

    // MARK: - 4. Mini Chart Card

    private var miniChartCard: some View {
        VStack(alignment: .leading, spacing: .spacingMd) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.formlogBlue)
                Text(L10n.string("本月趋势"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(Color.formlogTextPrimary)
                Spacer()
            }

            if monthEntries.count >= 2 {
                miniChartBody
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
            } else {
                VStack(spacing: .spacingSm) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
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
        let weights = monthEntries.compactMap { $0.value(for: .weight) }
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

    // MARK: - 5. Milestones Card

    private var milestonesCard: some View {
        let streak = entryStore.currentStreak
        let hasPhoto = photoCount > 0

        return VStack(alignment: .leading, spacing: .spacingMd) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.formlogOrange)
                Text(L10n.string("本月里程碑"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(Color.formlogTextPrimary)
                Spacer()
            }

            VStack(spacing: 0) {
                // Completion rate
                let completionRate = Int(Double(recordDays) / Double(daysInMonth) * 100)
                milestoneRow(
                    icon: "checkmark.circle.fill",
                    iconColor: completionRate >= 90 ? .formlogDecrease : (completionRate >= 50 ? .formlogPrimary : .formlogOrange),
                    title: L10n.string("记录完成率"),
                    value: "\(completionRate)%"
                )

                // Best streak
                if streak > 0 {
                    separatorInset
                    milestoneRow(
                        icon: "flame.fill",
                        iconColor: .formlogOrange,
                        title: L10n.string("本月最高连续"),
                        value: "\(streak)" + L10n.string("天")
                    )
                }

                // Photo count
                if hasPhoto {
                    separatorInset
                    milestoneRow(
                        icon: "camera.fill",
                        iconColor: .formlogPurple,
                        title: L10n.string("照片记录"),
                        value: "\(photoCount)" + L10n.string("张")
                    )
                }
            }
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusMd)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, .spacingLg)
        .padding(.vertical, .spacingLg)
        .blCard()
    }

    private func milestoneRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: .spacingMd) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                )

            Text(title)
                .font(.blBody)
                .foregroundColor(Color.formlogTextPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
                .monospacedDigit()
        }
        .padding(.horizontal, .spacingLg)
        .padding(.vertical, 14)
    }

    // MARK: - 6. Share Button

    private var shareButton: some View {
        Button {
            BodyLogHaptics.medium()
            shareReport()
        } label: {
            HStack(spacing: .spacingSm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text(L10n.string("分享月报"))
                    .font(.blBodySemibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.formlogPrimary)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        }
    }

    // MARK: - Shared Helpers

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

    // MARK: - Actions

    private func shareReport() {
        AchievementManager.shared.markShared()

        var shareText = L10n.string("月报标题") + "\n"
        shareText += "\(monthRangeString)\n\n"
        shareText += String(format: L10n.string("月报记录天数"), recordDays, daysInMonth) + "\n"
        shareText += String(format: L10n.string("月报记录次数"), monthEntries.count) + "\n"

        if let avg = monthAverageWeight {
            let display = appState.displayWeight(avg)
            shareText += String(format: L10n.string("月报平均体重"),
                                String(format: "%.1f", display.value),
                                display.unit) + "\n"
        }

        if let change = monthWeightChange {
            let sign = change >= 0 ? "+" : ""
            let display = appState.displayWeight(abs(change))
            shareText += String(format: L10n.string("月报体重变化"),
                                sign,
                                String(format: "%.1f", display.value),
                                display.unit) + "\n"
        }

        if let bfAvg = monthAverageBodyFat {
            shareText += String(format: L10n.string("月报平均体脂"), String(format: "%.1f", bfAvg)) + "\n"
        }

        if entryStore.currentStreak > 0 {
            shareText += String(format: L10n.string("月报连续天数"), entryStore.currentStreak) + "\n"
        }

        shareText += L10n.string("分享结尾")

        shareItems = [shareText]
        showShareSheet = true
    }
}

#Preview {
    MonthlyReportView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
