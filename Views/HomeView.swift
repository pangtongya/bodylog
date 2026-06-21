// HomeView.swift
// 首页：今日摘要 + 历史记录列表

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var showLogSheet: Bool

    @State private var showPhotoCompare: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 20) {
                        // 今日洞察卡片
                        todayInsightsCard
                            .padding(.horizontal, 20)

                        // 今日摘要卡片
                        summaryCard
                            .padding(.horizontal, 20)

                        // 快速统计
                        statsRow
                            .padding(.horizontal, 20)

                        // 照片对比入口（Pro 核心卖点）
                        photoCompareEntry
                            .padding(.horizontal, 20)

                        // 历史记录
                        historySection
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }

                // Achievement notification banner (fixed position overlay)
                if appState.showAchievementNotification,
                   let achievement = appState.latestUnlockedAchievement {
                    AchievementNotificationBanner(achievement: achievement, isPresented: $appState.showAchievementNotification)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        showLogSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.formlogPrimary)
                    }
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
        }
    }

    // MARK: - Today Insights Card
    
    private var todayInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title - more emotional
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("👋 \(greetingSuffix)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("用数据见证你的变化")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Insights
            let insights = todaysInsights
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.formlogPrimary)
                                .font(.system(size: 14))
                                .padding(.top, 2)
                            Text(insight)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            // 记录按钮已移至 summaryCard，此处不再重复
        }
        .padding(20)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private var greetingSuffix: String {
        appState.userName.isEmpty ? "" : "\(L10n.string("，"))\(appState.userName)"
    }

    private var todaysInsights: [String] {
        var result: [String] = []

        // Insight 1: Streak
        let streak = entryStore.currentStreak
        if streak > 0 {
            if streak >= 7 {
                result.append(String(format: L10n.string("🔥 已连续记录%d天，你太棒了！"), streak))
            } else {
                result.append(String(format: L10n.string("💪 已连续记录%d天，继续保持！"), streak))
            }
        } else if let lastEntry = entryStore.latestEntry {
            let days = Calendar.current.dateComponents([.day], from: lastEntry.recordedAt, to: Date()).day ?? 0
            if days == 1 {
                result.append(L10n.string("昨天记录了，今天继续吗？"))
            } else if days <= 7 {
                result.append(String(format: L10n.string("已%d天没有记录，今天开始吧"), days))
            } else {
                result.append(L10n.string("好久不见！记录一下今天的变化吧"))
            }
        } else {
            result.append(L10n.string("开始记录你的身体变化吧 💪"))
        }

        // Insight 2: Goal progress (if has active goal)
        if let goal = goalStore.activeGoals.first, let current = entryStore.latestValue(for: goal.metricType) {
            let remaining = abs(goal.targetValue - current)
            let unit = (goal.metricType == .weight || goal.metricType == .muscleMass) ? appState.weightUnit.rawValue : goal.metricType.unit
            if goal.isAchieved {
                result.append(String(format: L10n.string("🎉 恭喜！你已达成「%@」目标！"), goal.metricType.displayName))
            } else {
                result.append(String(format: L10n.string("距离「%@」目标还差%.1f%@"), goal.metricType.displayName, remaining, unit))
            }
        }

        return Array(result.prefix(2))
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("今日数据")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let latest = entryStore.latestEntry {
                    Text(relativeDate(latest.recordedAt))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            if entryStore.entries.isEmpty {
                emptyStateView
            } else {
                // 已启用指标的网格
                let enabled = appState.enabledMetrics
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(enabled) { metric in
                        metricCell(metric)
                    }
                }
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showLogSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(entryStore.entries.isEmpty ? L10n.string("记录第一条数据") : L10n.string("记录今天数据"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.formlogPrimary)
                .cornerRadius(12)
            }
            .contentShape(Rectangle())
        }
        .padding(20)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func metricCell(_ type: BodyMetricType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.formlogPrimary)
                Text(type.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            if let val = entryStore.latestValue(for: type) {
                let display = displayValue(val, for: type)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(display.value)
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    Text(display.unit)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                // Change indicator
                if let change = entryStore.change30Days(for: type) {
                    let isGood = isGoodChange(change, for: type)
                    HStack(spacing: 2) {
                        Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f", abs(change)))
                            .font(.system(size: 11, design: .rounded).monospacedDigit())
                        Text("30天")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(isGood ? .formlogDecrease : .formlogDanger)
                }
            } else {
                Text("未记录")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.systemGray3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.systemGray6)
        .cornerRadius(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Icons row
            HStack(spacing: 16) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 32))
                    .foregroundColor(.formlogPrimary)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.formlogPrimary)
                Image(systemName: "photo.stack")
                    .font(.system(size: 32))
                    .foregroundColor(.formlogPrimary)
            }
            
            VStack(spacing: 8) {
                Text("开始记录你的身体变化")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("记录体重、体脂、围度，见证每一次进步")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showLogSheet = true }) {
                Text("开始记录")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.formlogPrimary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Photo Compare Entry

    private var photoCompareEntry: some View {
        let photoCount = entryStore.entries.reduce(0) { $0 + ($1.hasPhoto ? 1 : 0) }
        let titleText = photoCount > 0
            ? String(format: L10n.string("已记录 %d 张形体照片"), photoCount)
            : L10n.string("用照片见证你的形体变化")

        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if appState.isPro {
                showPhotoCompare = true
            } else {
                showPaywall = true
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.formlogPrimary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.formlogPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("照片对比")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        if !appState.isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                    Text(titleText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.systemGray3)
            }
            .padding(16)
            .background(Color.systemBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(value: "\(entryStore.totalRecordDays)", labelKey: "记录天数")
            statCell(value: "\(entryStore.currentStreak)", labelKey: "连续天数")
            statCell(value: "\(entryStore.thisWeekCount)", labelKey: "本周记录")
        }
    }

    private func statCell(value: String, labelKey: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.formlogPrimary)
            Text(L10n.string(labelKey))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.systemBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 1)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史记录")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            if entryStore.entries.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(entryStore.groupedByDate.prefix(7), id: \.key) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.key)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)

                        ForEach(group.value) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)
                                .environmentObject(appState)
                                .environmentObject(entryStore)
                                .environmentObject(goalStore)
                                .environmentObject(purchaseManager)) {
                                EntryRowView(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.userName.isEmpty ? "" : "\(L10n.string("，"))\(appState.userName)"
        switch hour {
        case 5..<12: return L10n.string("早上好") + name
        case 12..<18: return L10n.string("下午好") + name
        default: return L10n.string("晚上好") + name
        }
    }

    // MARK: - Shared DateFormatters (cached)
    fileprivate static let relativeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    fileprivate static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L10n.string("今天") }
        if calendar.isDateInYesterday(date) { return L10n.string("昨天") }
        return Self.relativeDateFormatter.string(from: date)
    }

    private func displayValue(_ value: Double, for type: BodyMetricType) -> (value: String, unit: String) {
        if type == .weight || type == .muscleMass {
            let display = appState.displayWeight(value)
            return (String(format: "%.1f", display.value), display.unit)
        }
        return (String(format: "%.1f", value), type.unit)
    }

    /// 变化对于该指标是否是"好的"
    private func isGoodChange(_ change: Double, for type: BodyMetricType) -> Bool {
        switch type {
        case .weight, .bodyFat, .waist, .hip: return change < 0  // 减少是好事
        case .muscleMass: return change > 0  // 增加是好事
        default: return false
        }
    }
}

// MARK: - EntryRowView

struct EntryRowView: View {
    @EnvironmentObject var appState: AppState
    let entry: BodyEntry

    var body: some View {
        HStack(spacing: 12) {
            // 时间
            Text(timeString)
                .font(.system(size: 13, design: .rounded).monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)

            // 主要指标
            if let primary = entry.primaryMetric {
                HStack(spacing: 4) {
                    Image(systemName: primary.type.icon)
                        .font(.system(size: 13))
                        .foregroundColor(.formlogPrimary)
                    Text(formattedValue(primary.value, type: primary.type))
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    Text(primary.type.unit)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // 次要指标（最多2个）
            let secondaryMetrics = entry.metrics.keys
                .compactMap { BodyMetricType(rawValue: $0) }
                .filter { $0 != entry.primaryMetric?.type }
                .prefix(2)

            ForEach(Array(secondaryMetrics), id: \.self) { type in
                if let val = entry.value(for: type) {
                    HStack(spacing: 2) {
                        Text(formattedValue(val, type: type))
                            .font(.system(size: 13, design: .rounded).monospacedDigit())
                            .foregroundColor(.secondary)
                        Text(type.unit)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if entry.note != nil {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if entry.hasPhoto {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.systemGray3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }

    private var timeString: String {
        HomeView.timeFormatter.string(from: entry.recordedAt)
    }

    private func formattedValue(_ value: Double, type: BodyMetricType) -> String {
        if type == .weight || type == .muscleMass {
            let d = appState.displayWeight(value)
            return String(format: "%.1f", d.value)
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    HomeView(showLogSheet: .constant(false))
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
        .environmentObject(PurchaseManager.shared)
}
