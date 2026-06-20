// HomeView.swift
// 首页：今日摘要 + 历史记录列表

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var showLogSheet: Bool

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
                            .foregroundColor(.bodylogPrimary)
                    }
                }
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
                                .foregroundColor(.bodylogPrimary)
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
            
            // Quick action button
            if entryStore.entries.isEmpty || !Calendar.current.isDateInToday(entryStore.latestEntry?.recordedAt ?? Date.distantPast) {
                Button(action: { showLogSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("记录今天")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.bodylogPrimary)
                    .cornerRadius(10)
                }
                .contentShape(Rectangle())
            }
        }
        .padding(20)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    private var greetingSuffix: String {
        let name = appState.userName.isEmpty ? "" : "，\(appState.userName)"
        return name
    }

    private var todaysInsights: [String] {
        var result: [String] = []

        // Insight 1: Streak
        let streak = entryStore.currentStreak
        if streak > 0 {
            if streak >= 7 {
                result.append("🔥 已连续记录\(streak)天，你太棒了！")
            } else {
                result.append("💪 已连续记录\(streak)天，继续保持！")
            }
        } else if let lastEntry = entryStore.latestEntry {
            let days = Calendar.current.dateComponents([.day], from: lastEntry.recordedAt, to: Date()).day ?? 0
            if days == 1 {
                result.append("昨天记录了，今天继续吗？")
            } else if days <= 7 {
                result.append("已\(days)天没有记录，今天开始吧")
            } else {
                result.append("好久不见！记录一下今天的变化吧")
            }
        } else {
            result.append("开始记录你的身体变化吧 💪")
        }
        
        // Insight 2: Goal progress (if has active goal)
        if let goal = goalStore.activeGoals.first, let current = entryStore.latestValue(for: goal.metricType) {
            let remaining = abs(goal.targetValue - current)
            let unit = (goal.metricType == .weight || goal.metricType == .muscleMass) ? appState.weightUnit.rawValue : goal.metricType.unit
            if goal.isAchieved {
                result.append("🎉 恭喜！你已达成「\(goal.metricType.displayName)」目标！")
            } else {
                result.append("距离「\(goal.metricType.displayName)」目标还差\(String(format: "%.1f", remaining))\(unit)")
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
                    Text(entryStore.entries.isEmpty ? "记录第一条数据" : "记录今天数据")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bodylogPrimary)
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
                    .foregroundColor(.bodylogPrimary)
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
                    .foregroundColor(isGood ? .bodylogDecrease : .bodylogDanger)
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
                    .foregroundColor(.bodylogPrimary)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.bodylogPrimary)
                Image(systemName: "photo.stack")
                    .font(.system(size: 32))
                    .foregroundColor(.bodylogPrimary)
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
                    .background(Color.bodylogPrimary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(value: "\(entryStore.totalRecordDays)", label: "记录天数")
            statCell(value: "\(entryStore.currentStreak)", label: "连续天数")
            statCell(value: "\(entryStore.thisWeekCount)", label: "本周记录")
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.bodylogPrimary)
            Text(label)
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
        let name = appState.userName.isEmpty ? "" : "，\(appState.userName)"
        switch hour {
        case 5..<12: return "早上好\(name)"
        case 12..<18: return "下午好\(name)"
        default: return "晚上好\(name)"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func displayValue(_ value: Double, for type: BodyMetricType) -> (value: String, unit: String) {
        if type == .weight || type == .muscleMass {
            let display = appState.displayWeight(value)
            return (String(format: "%.1f", display.value), display.unit)
        }
        if type == .bodyFat || type == .bmi {
            return (String(format: "%.1f", value), type.unit)
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
                        .foregroundColor(.bodylogPrimary)
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
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.recordedAt)
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
