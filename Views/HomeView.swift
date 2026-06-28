// HomeView.swift
// Home screen: Apple HIG-style premium layout
// Calm, spacious, data-forward with ring progress and generous white space

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var showLogSheet: Bool

    @State private var showPhotoCompare: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showWeeklyReport: Bool = false
    @State private var showMonthlyReport: Bool = false

    var body: some View {
        NavigationStack {
            if appState.hasCompletedOnboarding {
                homeContent
            } else {
                OnboardingView()
            }
        }
        .sheet(isPresented: $showPhotoCompare) {
            PhotoCompareView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showWeeklyReport) {
            WeeklyReportView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
        .sheet(isPresented: $showMonthlyReport) {
            MonthlyReportView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
    }

    // MARK: - Home Content

    private var homeContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Safe area top spacer
                    Color.clear.frame(height: 8)

                    // 1. Greeting Section
                    greetingSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // 2. Achievement Progress Banner
                    achievementBanner
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 3. Hero Ring Section
                    heroRingSection
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    // 4. Metric Pills
                    metricPillsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // 5. Insight Cards
                    insightCardsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 6. Quick Stats
                    quickStatsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 7. Reports Section
                    reportsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    // 8. History Section
                    historySection
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 120)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.formlogBgGrouped)
            .refreshable {
                entryStore.reloadFromDisk()
            }

            // Floating Action Button
            floatingActionButton

            // Achievement notification banner
            if appState.showAchievementNotification,
               let achievement = appState.latestUnlockedAchievement {
                VStack {
                    AchievementNotificationBanner(
                        achievement: achievement,
                        isPresented: $appState.showAchievementNotification
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Floating Action Button

    private var floatingActionButton: some View {
        Button(action: {
            BodyLogHaptics.heavy()
            showLogSheet = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.formlogPrimary)
                    .frame(width: 56, height: 56)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
    }

    // MARK: - 1. Greeting Section

    private var greetingSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.formlogTextPrimary)
                    .tracking(-0.5)

                Text(L10n.string("用数据见证你的变化"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
            }

            Spacer()

            // Avatar circle with initial
            avatarCircle
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.userName.isEmpty ? "" : "\(L10n.string("，"))\(appState.userName)"
        switch hour {
        case 5..<12: return L10n.string("早上好") + name
        case 12..<18: return L10n.string("下午好") + name
        default: return L10n.string("晚上好") + name
        }
    }

    private var avatarCircle: some View {
        let initial = appState.userName.isEmpty ? "?"
            : String(appState.userName.prefix(1))
        return ZStack {
            Circle()
                .fill(Color.formlogPrimary.opacity(0.10))
                .frame(width: 44, height: 44)
            Text(initial)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.formlogPrimary)
        }
    }

    // MARK: - 2. Achievement Progress Banner

    private var achievementBanner: some View {
        let nextAchievement = getNextAchievement()
        return Group {
            if let achievement = nextAchievement {
                Button(action: {
                    BodyLogHaptics.light()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.formlogPrimary.opacity(0.10))
                                .frame(width: 32, height: 32)
                            Image(systemName: achievement.type.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.formlogPrimary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(L10n.string("即将解锁: ") + achievement.type.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.formlogTextPrimary)
                                Spacer()
                                Text("\(achievement.current)/\(achievement.target)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.formlogTextSecondary)
                                    .monospacedDigit()
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color.formlogFillTertiary)
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color.formlogPrimary)
                                        .frame(
                                            width: geo.size.width * min(
                                                Double(achievement.current) / Double(achievement.target),
                                                1.0
                                            ),
                                            height: 4
                                        )
                                }
                            }
                            .frame(height: 4)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.formlogTextTertiary)
                    }
                    .padding(12)
                    .background(Color.formlogCard)
                    .cornerRadius(CGFloat.radiusMd)
                    .overlay(
                        RoundedRectangle(cornerRadius: CGFloat.radiusMd)
                            .stroke(Color.formlogSeparator, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func getNextAchievement() -> (type: AchievementType, current: Int, target: Int)? {
        let unlockedIds = Set(appState.achievements.map { $0.id })
        var closest: (type: AchievementType, current: Int, target: Int, progress: Double)?

        for type in AchievementType.allCases {
            if unlockedIds.contains(type.id) { continue }
            if let progress = AchievementManager.shared.progress(
                for: type,
                entryStore: entryStore,
                goalStore: goalStore
            ) {
                let p = Double(progress.current) / Double(progress.target)
                if let currentClosest = closest {
                    if p > currentClosest.progress {
                        closest = (type, progress.current, progress.target, p)
                    }
                } else {
                    closest = (type, progress.current, progress.target, p)
                }
            }
        }

        guard let c = closest else { return nil }
        return (c.type, c.current, c.target)
    }

    // MARK: - 3. Hero Ring Section

    private var heroRingSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background track ring
                Circle()
                    .stroke(Color.formlogFillTertiary, lineWidth: 14)
                    .frame(width: 220, height: 220)

                // Progress ring
                if let progress = goalProgress {
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(
                            Color.formlogPrimary,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: progress)
                }

                // Center content
                VStack(spacing: 6) {
                    if let latestWeight = entryStore.latestValue(for: .weight) {
                        let display = appState.displayWeight(latestWeight)
                        Text(String(format: "%.1f", display.value))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.formlogTextPrimary)
                            .tracking(-1)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(display.unit)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.formlogTextSecondary)
                            .textCase(.uppercase)
                    } else {
                        Text("--")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.formlogTextTertiary)
                        Text(appState.weightUnit.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.formlogTextTertiary)
                            .textCase(.uppercase)
                    }
                }
            }

            // Today's date label
            Text(todayDateString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var goalProgress: Double? {
        guard let goal = goalStore.activeGoal(for: .weight),
              let current = entryStore.latestValue(for: .weight),
              let start = entryStore.startValue(for: .weight) else {
            return nil
        }
        return goal.progress(currentValue: current, startValue: start)
    }

    private static let todayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMMM d, EEEE"
        return f
    }()

    private var todayDateString: String {
        Self.todayFormatter.string(from: Date())
    }

    // MARK: - 4. Metric Pills Row

    private var metricPillsRow: some View {
        HStack(spacing: 12) {
            ForEach(displayMetrics, id: \.self) { metric in
                metricPill(metric)
            }
        }
    }

    private var displayMetrics: [BodyMetricType] {
        let enabled = appState.enabledMetrics
        if enabled.isEmpty { return [.weight, .bodyFat, .muscleMass] }
        return Array(enabled.prefix(3))
    }

    private func metricPill(_ type: BodyMetricType) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 11))
                    .foregroundColor(metricColor(for: type))
                Text(type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
            }

            if let val = entryStore.latestValue(for: type) {
                let display = displayValue(val, for: type)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(display.value)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.formlogTextPrimary)
                        .monospacedDigit()
                    Text(display.unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.formlogTextSecondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.formlogTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color.formlogCard)
        .cornerRadius(CGFloat.radiusXl)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
    }

    private func metricColor(for type: BodyMetricType) -> Color {
        switch type {
        case .weight, .muscleMass: return .formlogPrimary
        case .bodyFat: return .formlogBlue
        case .bmi: return .formlogOrange
        default: return .formlogPurple
        }
    }

    // MARK: - 5. Insight Cards

    private var insightCardsSection: some View {
        let insights = todaysInsights
        return Group {
            if !insights.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                        insightCard(
                            insight,
                            color: index == 0 ? .formlogPrimary : .formlogBlue
                        )
                    }
                }
            }
        }
    }

    private func insightCard(
        _ insight: (title: String, subtitle: String),
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.formlogTextPrimary)

                Text(insight.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.formlogTextSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.formlogCard)
        .cornerRadius(CGFloat.radiusXl)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
    }

    private var todaysInsights: [(title: String, subtitle: String)] {
        var result: [(title: String, subtitle: String)] = []

        // Insight 1: Streak
        let streak = entryStore.currentStreak
        if streak > 0 {
            if streak >= 7 {
                result.append((
                    title: String(format: L10n.string("🔥 已连续记录%d天"), streak),
                    subtitle: L10n.string("继续保持，习惯正在养成")
                ))
            } else {
                result.append((
                    title: String(format: L10n.string("💪 已连续记录%d天"), streak),
                    subtitle: L10n.string("继续保持，好的开始是成功的一半")
                ))
            }
        } else if let lastEntry = entryStore.latestEntry {
            let days = Calendar.current.dateComponents(
                [.day],
                from: lastEntry.recordedAt,
                to: Date()
            ).day ?? 0
            if days == 1 {
                result.append((
                    title: L10n.string("昨天记录了"),
                    subtitle: L10n.string("今天继续吗？")
                ))
            } else if days <= 7 {
                result.append((
                    title: String(format: L10n.string("已%d天没有记录"), days),
                    subtitle: L10n.string("今天开始吧")
                ))
            } else {
                result.append((
                    title: L10n.string("好久不见！"),
                    subtitle: L10n.string("记录一下今天的变化吧")
                ))
            }
        } else {
            result.append((
                title: L10n.string("开始记录你的身体变化吧 💪"),
                subtitle: L10n.string("点击右下角按钮开始记录")
            ))
        }

        // Insight 2: Goal progress
        if let goal = goalStore.activeGoals.first,
           let current = entryStore.latestValue(for: goal.metricType) {
            let remaining = abs(goal.targetValue - current)
            let unit = (goal.metricType == .weight || goal.metricType == .muscleMass)
                ? appState.weightUnit.rawValue : goal.metricType.unit

            if goal.isAchieved {
                result.append((
                    title: String(
                        format: L10n.string("🎉 恭喜！你已达成「%@」目标！"),
                        goal.metricType.displayName
                    ),
                    subtitle: L10n.string("继续保持良好的状态")
                ))
            } else {
                let targetDisplay = displayValue(goal.targetValue, for: goal.metricType)
                result.append((
                    title: String(
                        format: L10n.string("距离目标还差%.1f%@"), remaining, unit
                    ),
                    subtitle: String(
                        format: L10n.string("%@目标：%@%@"),
                        goal.metricType.displayName,
                        targetDisplay.value,
                        targetDisplay.unit
                    )
                ))
            }
        }

        return Array(result.prefix(2))
    }

    // MARK: - 6. Quick Stats Row

    private var quickStatsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(entryStore.totalRecordDays)",
                label: L10n.string("记录天数"),
                highlight: false
            )

            Rectangle()
                .fill(Color.formlogSeparator)
                .frame(width: 0.5, height: 44)

            statCell(
                value: "\(entryStore.currentStreak)",
                label: L10n.string("连续天数"),
                highlight: true
            )

            Rectangle()
                .fill(Color.formlogSeparator)
                .frame(width: 0.5, height: 44)

            statCell(
                value: "\(entryStore.thisWeekCount)",
                label: L10n.string("本周记录"),
                highlight: false
            )
        }
        .padding(.vertical, 16)
        .background(Color.formlogCard)
        .cornerRadius(CGFloat.radiusXl)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
    }

    private func statCell(value: String, label: String, highlight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(highlight ? .formlogPrimary : .formlogTextPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 7. Reports Section

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L10n.string("报告"))

            HStack(spacing: 12) {
                reportCard(
                    title: L10n.string("周报"),
                    subtitle: L10n.string("本周数据总结"),
                    icon: "calendar.badge.clock",
                    color: .formlogPrimary
                ) {
                    BodyLogHaptics.light()
                    showWeeklyReport = true
                }

                reportCard(
                    title: L10n.string("月报"),
                    subtitle: L10n.string("本月里程碑"),
                    icon: "chart.bar.doc.horizontal",
                    color: .formlogBlue
                ) {
                    BodyLogHaptics.light()
                    showMonthlyReport = true
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.formlogTextSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.leading, 4)
    }

    private func reportCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(color)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.formlogTextTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.formlogTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.formlogTextSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.formlogCard)
            .cornerRadius(CGFloat.radiusXl)
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat.radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 8. History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L10n.string("历史记录"))

            if entryStore.entries.isEmpty {
                emptyHistoryView
            } else {
                historyList
            }
        }
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(.formlogTextTertiary)
            Text(L10n.string("暂无记录"))
                .font(.system(size: 15))
                .foregroundColor(.formlogTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.formlogCard)
        .cornerRadius(CGFloat.radiusXl)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
    }

    private var historyList: some View {
        let groups = Array(entryStore.groupedByDate.prefix(2))
        return VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { sectionIndex, group in
                VStack(alignment: .leading, spacing: 0) {
                    // Date section header
                    Text(group.key)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.formlogTextSecondary)
                        .padding(.top, sectionIndex == 0 ? 0 : 20)
                        .padding(.bottom, 8)
                        .padding(.leading, 4)

                    // Entries card for this date
                    VStack(spacing: 0) {
                        ForEach(
                            Array(group.value.prefix(3).enumerated()),
                            id: \.element.id
                        ) { entryIndex, entry in
                            NavigationLink(
                                destination: EntryDetailView(entryID: entry.id)
                                    .environmentObject(appState)
                                    .environmentObject(entryStore)
                                    .environmentObject(goalStore)
                                    .environmentObject(purchaseManager)
                            ) {
                                HistoryRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    BodyLogHaptics.medium()
                                    entryStore.deleteEntry(id: entry.id)
                                } label: {
                                    Label(L10n.string("删除"), systemImage: "trash")
                                }
                                .tint(.red)
                            }

                            if entryIndex < min(group.value.count, 3) - 1 {
                                Rectangle()
                                    .fill(Color.formlogSeparator)
                                    .frame(height: 0.5)
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .background(Color.formlogCard)
                    .cornerRadius(CGFloat.radiusXl)
                    .overlay(
                        RoundedRectangle(cornerRadius: CGFloat.radiusXl)
                            .stroke(Color.formlogSeparator, lineWidth: 1)
                    )
                    .animation(.easeOut(duration: 0.3), value: entryStore.entries.count)
                }
            }
        }
    }

    // MARK: - Helpers

    private func displayValue(
        _ value: Double,
        for type: BodyMetricType
    ) -> (value: String, unit: String) {
        if type == .weight || type == .muscleMass {
            let display = appState.displayWeight(value)
            return (String(format: "%.1f", display.value), display.unit)
        }
        return (String(format: "%.1f", value), type.unit)
    }
}

// MARK: - HistoryRowView

struct HistoryRowView: View {
    @EnvironmentObject var appState: AppState
    let entry: BodyEntry

    var body: some View {
        HStack(spacing: 14) {
            // Time
            Text(timeString)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .frame(width: 48, alignment: .leading)

            // Main content
            VStack(alignment: .leading, spacing: 3) {
                if let primary = entry.primaryMetric {
                    let display = formattedValue(primary.value, type: primary.type)
                    Text("\(display.value) \(display.unit)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.formlogTextPrimary)
                }

                let secondaryMetrics = entry.metrics.keys
                    .compactMap { BodyMetricType(rawValue: $0) }
                    .filter { $0 != entry.primaryMetric?.type }
                    .prefix(2)

                if !secondaryMetrics.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(Array(secondaryMetrics), id: \.self) { type in
                            if let val = entry.value(for: type) {
                                let display = formattedValue(val, type: type)
                                Text("\(type.displayName) \(display.value)\(display.unit)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.formlogTextSecondary)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Indicators
            HStack(spacing: 6) {
                if entry.note != nil {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 11))
                        .foregroundColor(.formlogTextTertiary)
                }
                if entry.hasPhoto {
                    Image(systemName: "photo")
                        .font(.system(size: 11))
                        .foregroundColor(.formlogTextTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.formlogTextQuaternary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("HHmm")
        return f
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: entry.recordedAt)
    }

    private func formattedValue(
        _ value: Double,
        type: BodyMetricType
    ) -> (value: String, unit: String) {
        if type == .weight || type == .muscleMass {
            let d = appState.displayWeight(value)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", value), type.unit)
    }
}

#Preview {
    HomeView(showLogSheet: .constant(false))
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
        .environmentObject(PurchaseManager.shared)
}
