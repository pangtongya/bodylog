// GoalsView.swift
// Premium Apple HIG-style goals screen with Activity Ring hero

import SwiftUI

// MARK: - GoalsView

struct GoalsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var showAddGoal: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Header
                    headerSection
                        .padding(.bottom, 20)

                    if goalStore.activeGoals.isEmpty && goalStore.achievedGoals.isEmpty {
                        emptyState
                    } else {
                        // 2. Hero Ring for primary goal
                        if let primaryGoal = goalStore.activeGoals.first {
                            heroRingSection(goal: primaryGoal)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                        }

                        // 3. Other active goals
                        if goalStore.activeGoals.count > 1 {
                            activeGoalsSection
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                        }

                        // 4. Achieved goals
                        if !goalStore.achievedGoals.isEmpty {
                            achievedGoalsSection
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .background(Color.formlogBgGrouped)
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        BodyLogHaptics.heavy()
                        if !appState.isPro && goalStore.activeGoals.count >= 2 {
                            showPaywall = true
                        } else {
                            showAddGoal = true
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.formlogPrimary)
                    }
                    .accessibilityLabel("Add new goal")
                    .accessibilityHint("Double tap to set a new body data goal")
                }
            }
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalView(isPresented: $showAddGoal)
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(purchaseManager)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(L10n.string("目标"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.formlogTextPrimary)
                .tracking(-0.5)

            if !goalStore.activeGoals.isEmpty {
                Text("\(goalStore.activeGoals.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.formlogPrimary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: - Hero Ring Section

    private func heroRingSection(goal: GoalModel) -> some View {
        let current = entryStore.latestValue(for: goal.metricType)
        let start = entryStore.startValue(for: goal.metricType)
        let clampedProgress = min(max(goalProgress(goal: goal, current: current, start: start), 0), 1)

        return VStack(spacing: 20) {
            // Activity Ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.formlogFillTertiary, lineWidth: 14)

                // Progress arc
                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(
                        Color.formlogPrimary,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: clampedProgress)

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(clampedProgress * 100))%")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.formlogTextPrimary)
                        .tracking(-1)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(goal.metricType.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.formlogTextSecondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding(.top, 8)

            // Direction badge
            directionBadge(goal.direction)

            // Start -> Target
            HStack(spacing: 0) {
                if let s = start {
                    let startDisp = formatValue(s, for: goal.metricType)
                    VStack(spacing: 2) {
                        Text(startDisp.0)
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .foregroundColor(.formlogTextPrimary)
                        Text(L10n.string("起始"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.formlogTextTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
                    .frame(width: 44, alignment: .center)

                let targetDisp = formatValue(goal.targetValue, for: goal.metricType)
                VStack(spacing: 2) {
                    Text(targetDisp.0)
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .foregroundColor(.formlogPrimary)
                    Text(L10n.string("目标"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.formlogTextTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .padding(24)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Goal progress \(Int(clampedProgress * 100))%")
        .accessibilityValue("\(goal.metricType.displayName), from \(formatValue(start ?? goal.targetValue, for: goal.metricType).0) to \(formatValue(goal.targetValue, for: goal.metricType).0)")
    }

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L10n.string("其他目标"))

            ForEach(goalStore.activeGoals.dropFirst()) { goal in
                GoalCardView(goal: goal)
            }
        }
    }

    // MARK: - Achieved Goals Section

    private var achievedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L10n.string("已达成"))

            // Celebration banner
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.formlogPrimary)
                Text(L10n.string("恭喜你达成了目标！"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.formlogPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ForEach(goalStore.achievedGoals) { goal in
                GoalCardView(goal: goal, isAchieved: true)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            // Free tier notice
            if !appState.isPro {
                let remaining = max(0, 2 - goalStore.activeGoals.count)
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: remaining == 0 ? "lock.fill" : "info.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(remaining == 0 ? .formlogOrange : .formlogBlue)
                        if remaining == 0 {
                            Text(L10n.string("免费版最多 2 个目标"))
                                .font(.system(size: 13))
                                .foregroundColor(.formlogTextSecondary)
                        } else {
                            Text(String(format: L10n.string("免费版还可创建 %d 个目标"), remaining))
                                .font(.system(size: 13))
                                .foregroundColor(.formlogTextSecondary)
                        }
                    }
                    if remaining == 0 {
                        Button(action: { showPaywall = true }) {
                            Text(L10n.string("升级到 Pro，无限目标"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.formlogPrimary)
                        }
                    }
                }
                .padding(.top, 8)
            }

            // Large icon
            ZStack {
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "target")
                    .font(.system(size: 48))
                    .foregroundColor(.formlogPrimary)
            }

            // Text
            VStack(spacing: 8) {
                Text(L10n.string("设置你的第一个目标"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.formlogTextPrimary)
                Text(L10n.string("有了目标，改变更有方向\n让数据见证你的进步 ✨"))
                    .font(.system(size: 15))
                    .foregroundColor(.formlogTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // CTA button
            Button(action: { showAddGoal = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(L10n.string("设置目标"))
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.formlogPrimary)
                .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            }
            .padding(.horizontal, 20)
            .accessibilityLabel("Set goal")
            .accessibilityHint("Double tap to set your first body data goal")
        }
        .padding(.top, 48)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.formlogTextSecondary)
            .textCase(.uppercase)
            .tracking(0.2)
            .padding(.leading, 4)
    }

    private func directionBadge(_ direction: GoalModel.Direction) -> some View {
        let (text, color): (String, Color) = {
            switch direction {
            case .decrease: return (L10n.string("降低"), .formlogDecrease)
            case .increase: return (L10n.string("增加"), .formlogOrange)
            case .maintain: return (L10n.string("维持"), .formlogBlue)
            }
        }()

        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func goalProgress(goal: GoalModel, current: Double?, start: Double?) -> Double {
        guard let c = current, let s = start else { return 0 }
        return goal.progress(currentValue: c, startValue: s)
    }

    private func formatValue(_ val: Double, for metric: BodyMetricType) -> (String, String) {
        if metric == .weight || metric == .muscleMass {
            let d = appState.displayWeight(val)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", val), metric.unit)
    }
}

// MARK: - GoalCardView

struct GoalCardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore

    let goal: GoalModel
    var isAchieved: Bool = false

    @State private var showDeleteAlert: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []

    private var currentValue: Double? { entryStore.latestValue(for: goal.metricType) }
    private var startValue: Double? { entryStore.startValue(for: goal.metricType) }

    private var progress: Double {
        guard let current = currentValue, let start = startValue else { return 0 }
        return goal.progress(currentValue: current, startValue: start)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Row 1: Icon + Name + Direction Badge + Target Value
            HStack(spacing: 12) {
                // Metric icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isAchieved
                              ? Color.formlogDecrease.opacity(0.12)
                              : Color.formlogPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: goal.metricType.icon)
                        .font(.system(size: 17))
                        .foregroundColor(isAchieved ? .formlogDecrease : .formlogPrimary)
                }

                // Name + Direction
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.metricType.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.formlogTextPrimary)
                    directionBadge(goal.direction)
                }

                Spacer()

                // Target value (right-aligned)
                let targetDisp = formattedTarget
                VStack(alignment: .trailing, spacing: 2) {
                    Text(targetDisp.0)
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .foregroundColor(isAchieved ? .formlogDecrease : .formlogTextPrimary)
                    Text(targetDisp.1)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.formlogTextTertiary)
                }

                // Share button for achieved goals
                if isAchieved {
                    Button(action: {
                        BodyLogHaptics.light()
                        shareGoal()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(.formlogDecrease)
                    }
                    .sheet(isPresented: $showShareSheet) {
                        ShareSheet(items: shareItems)
                    }
                }
            }

            // Row 2: Current value
            if !isAchieved, let current = currentValue {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.upward")
                        .font(.system(size: 12))
                        .foregroundColor(.formlogTextTertiary)
                    Text(String(format: L10n.string("当前：%@"), formatVal(current)))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundColor(.formlogTextSecondary)
                    Spacer()
                }
            }

            // Row 3: Progress bar
            if !isAchieved {
                VStack(alignment: .leading, spacing: 6) {
                    // Thin progress bar (4px)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.formlogFillTertiary)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.formlogPrimary)
                            .frame(width: geo.size.width * clampedProgress, height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: clampedProgress)
                    }
                    .frame(height: 4)

                    // Percentage + motivation
                    HStack {
                        Text("\(Int(clampedProgress * 100))%")
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundColor(.formlogPrimary)
                        Spacer()
                        motivationalText(clampedProgress)
                    }
                }
            } else {
                // Achieved celebration
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13))
                    Text(L10n.string("恭喜你达成了目标！"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.formlogTextSecondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(
                    isAchieved ? Color.formlogDecrease.opacity(0.3) : Color.formlogSeparator,
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAchieved
            ? "Achieved: \(goal.metricType.displayName) goal reached, \(formattedTarget.0) \(formattedTarget.1)"
            : "\(goal.metricType.displayName) goal, progress \(Int(clampedProgress * 100))%, current \(currentValue.map { formatVal($0) } ?? "no data")")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                BodyLogHaptics.medium()
                showDeleteAlert = true
            } label: {
                Label(L10n.string("删除"), systemImage: "trash")
            }
            .tint(.red)
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label(L10n.string("删除目标"), systemImage: "trash")
            }
        }
        .alert(L10n.string("删除目标"), isPresented: $showDeleteAlert) {
            Button(L10n.string("删除"), role: .destructive) {
                BodyLogHaptics.heavy()
                goalStore.deleteGoal(id: goal.id)
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            Text(L10n.string("确定要删除这个目标吗？"))
        }
    }

    // MARK: - Helpers

    private func directionBadge(_ direction: GoalModel.Direction) -> some View {
        let (text, color): (String, Color) = {
            switch direction {
            case .decrease: return (L10n.string("降低"), .formlogDecrease)
            case .increase: return (L10n.string("增加"), .formlogOrange)
            case .maintain: return (L10n.string("维持"), .formlogBlue)
            }
        }()

        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func motivationalText(_ progress: Double) -> some View {
        Group {
            if progress >= 1.0 {
                Text(L10n.string("目标已达成！"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogDecrease)
            } else if progress >= 0.8 {
                Text(L10n.string("马上就要达成了！💪"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogPrimary)
            } else if progress >= 0.5 {
                Text(L10n.string("继续加油！"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
            } else if progress > 0 {
                Text(L10n.string("刚刚起步"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formlogTextTertiary)
            }
        }
    }

    private func formatVal(_ val: Double) -> String {
        if goal.metricType == .weight || goal.metricType == .muscleMass {
            let d = appState.displayWeight(val)
            return String(format: "%.1f %@", d.value, d.unit)
        }
        return String(format: "%.1f %@", val, goal.metricType.unit)
    }

    private func shareGoal() {
        let message = String(format: L10n.string("""
🎉 我在FormLog达成了身体数据目标！

%@: %@%@ 用数据记录身体变化，见证每一次进步 💪
"""), goal.metricType.displayName, formattedTarget.0, formattedTarget.1)
        shareItems = [message]
        showShareSheet = true
    }

    private var formattedTarget: (String, String) {
        if goal.metricType == .weight || goal.metricType == .muscleMass {
            let d = appState.displayWeight(goal.targetValue)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", goal.targetValue), goal.metricType.unit)
    }
}

// MARK: - AddGoalView

struct AddGoalView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @Binding var isPresented: Bool

    @State private var selectedMetric: BodyMetricType = .weight
    @State private var targetStr: String = ""
    @State private var direction: GoalModel.Direction = .decrease
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Metric picker
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(L10n.string("选择指标"))
                        VStack(spacing: 0) {
                            ForEach(appState.enabledMetrics) { metric in
                                Button(action: {
                                    BodyLogHaptics.light()
                                    selectedMetric = metric
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(
                                                    (selectedMetric == metric
                                                     ? Color.formlogPrimary
                                                     : Color.formlogBlue)
                                                    .opacity(selectedMetric == metric ? 0.15 : 0.1)
                                                )
                                                .frame(width: 40, height: 40)
                                            Image(systemName: metric.icon)
                                                .font(.system(size: 17))
                                                .foregroundColor(
                                                    selectedMetric == metric
                                                        ? .formlogPrimary
                                                        : .formlogBlue
                                                )
                                        }
                                        Text(metric.displayName)
                                            .font(.system(size: 17))
                                            .foregroundColor(.formlogTextPrimary)
                                        Spacer()
                                        if selectedMetric == metric {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.formlogPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color.formlogCard)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusXl)
                                .stroke(Color.formlogSeparator, lineWidth: 1)
                        )
                    }

                    // Direction picker
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(L10n.string("目标方向"))
                        HStack(spacing: 8) {
                            ForEach([GoalModel.Direction.decrease, .maintain, .increase], id: \.self) { d in
                                Button(action: {
                                    BodyLogHaptics.light()
                                    direction = d
                                }) {
                                    VStack(spacing: 6) {
                                        Image(systemName: d.icon)
                                            .font(.system(size: 22))
                                        Text(d.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(direction == d ? .white : .formlogTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(direction == d ? Color.formlogPrimary : Color.formlogCard)
                                    .clipShape(RoundedRectangle(cornerRadius: .radiusLg))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: .radiusLg)
                                            .stroke(
                                                direction == d ? Color.formlogPrimary : Color.formlogSeparator,
                                                lineWidth: 1
                                            )
                                    )
                                }
                            }
                        }
                    }

                    // Target value
                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(L10n.string("目标值"))
                        let unitStr = (selectedMetric == .weight || selectedMetric == .muscleMass)
                            ? appState.weightUnit.rawValue : selectedMetric.unit
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                TextField(L10n.string("例如 70"), text: $targetStr)
                                    .font(.system(size: 30, weight: .semibold).monospacedDigit())
                                    .keyboardType(.decimalPad)
                                Text(unitStr)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.formlogTextSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)

                            if let current = entryStore.latestValue(for: selectedMetric) {
                                let disp = displayCurrent(current)
                                HStack {
                                    Text(String(format: L10n.string("当前：%@ %@"), disp.0, disp.1))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.formlogTextSecondary)
                                    Spacer()
                                    Button(action: { targetStr = disp.0 }) {
                                        Text(L10n.string("使用当前值"))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.formlogPrimary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                            }
                        }
                        .background(Color.formlogCard)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusXl)
                                .stroke(Color.formlogSeparator, lineWidth: 1)
                        )
                    }

                    // Save button
                    Button(action: addGoal) {
                        Text(L10n.string("创建目标"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.formlogPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color.formlogBgGrouped)
            .navigationTitle(L10n.string("设置目标"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) { isPresented = false }
                        .foregroundColor(.formlogBlue)
                }
            }
            .alert(L10n.string("输入有误"), isPresented: $showError) {
                Button(L10n.string("好的"), role: .cancel) {}
            } message: {
                Text(L10n.string("请输入有效的目标值"))
            }
            .onAppear {
                if let first = appState.enabledMetrics.first { selectedMetric = first }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.formlogTextSecondary)
            .textCase(.uppercase)
            .tracking(0.2)
            .padding(.leading, 4)
    }

    private func addGoal() {
        guard let val = Double(targetStr.trimmingCharacters(in: .whitespaces)), val > 0 else {
            showError = true; return
        }
        let storeVal: Double
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            storeVal = appState.toKg(val)
        } else {
            storeVal = val
        }
        BodyLogHaptics.heavy()
        goalStore.addGoal(GoalModel(metricType: selectedMetric, targetValue: storeVal, direction: direction))
        isPresented = false
    }

    private func displayCurrent(_ val: Double) -> (String, String) {
        if selectedMetric == .weight || selectedMetric == .muscleMass {
            let d = appState.displayWeight(val)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", val), selectedMetric.unit)
    }
}

#Preview {
    GoalsView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
        .environmentObject(PurchaseManager.shared)
}
