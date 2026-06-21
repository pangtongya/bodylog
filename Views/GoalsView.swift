// GoalsView.swift
// 目标设定与追踪

import SwiftUI

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
                VStack(spacing: 20) {
                    if goalStore.activeGoals.isEmpty && goalStore.achievedGoals.isEmpty {
                        emptyState
                    } else {
                        // Active Goals
                        if !goalStore.activeGoals.isEmpty {
                            sectionHeader("进行中的目标")
                            ForEach(goalStore.activeGoals) { goal in
                                GoalCardView(goal: goal)
                            }
                        }

                        // Achieved Goals
                        if !goalStore.achievedGoals.isEmpty {
                            sectionHeader("已达成")
                            ForEach(goalStore.achievedGoals) { goal in
                                GoalCardView(goal: goal, isAchieved: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        if !appState.isPro && goalStore.activeGoals.count >= 2 {
                            showPaywall = true
                        } else {
                            showAddGoal = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            if !appState.isPro && goalStore.activeGoals.count >= 2 {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                            }
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                        }
                        .foregroundColor(.formlogPrimary)
                    }
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            // Free tier hint
            if !appState.isPro && goalStore.activeGoals.count >= 2 {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("免费版最多 2 个目标")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Button(action: { showPaywall = true }) {
                        Text("升级到 Pro，无限目标")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.formlogPrimary)
                    }
                }
                .padding(.top, 8)
            }

            ZStack {
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "target")
                    .font(.system(size: 44))
                    .foregroundColor(.formlogPrimary)
            }

            VStack(spacing: 8) {
                Text("设定你的第一个目标")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Text("有了目标，改变更有方向\n让数据见证你的进步 ✨")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: { showAddGoal = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("设置目标")
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.formlogPrimary)
                .cornerRadius(14)
                .shadow(color: .formlogPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 40)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        VStack(spacing: 0) {
            // Celebration banner (when achieved)
            if isAchieved {
                HStack(spacing: 6) {
                    Image(systemName: "party.popper.fill")
                    Text("目标已达成！")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "party.popper.fill")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.formlogDecrease, .formlogDecrease.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }

            // Card content
            VStack(spacing: 14) {
                // Header
                HStack {
                    Image(systemName: goal.metricType.icon)
                        .foregroundColor(isAchieved ? .formlogDecrease : .formlogPrimary)
                    Text(goal.metricType.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    if isAchieved {
                        Label("已达成", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.formlogDecrease)
                    } else {
                        Image(systemName: goal.direction.icon)
                            .foregroundColor(.formlogPrimary.opacity(0.7))
                    }

                    // Share button (when achieved)
                    if isAchieved {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            shareGoal()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(.formlogDecrease)
                        }
                        .sheet(isPresented: $showShareSheet) {
                            ShareSheet(items: shareItems)
                        }
                    }
                }

                // Target
                HStack(alignment: .lastTextBaseline) {
                    Text(goal.direction.displayName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    let targetDisplay = formattedTarget
                    Text(targetDisplay.0)
                        .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(isAchieved ? .formlogDecrease : .formlogPrimary)
                    Text(targetDisplay.1)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let current = currentValue {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("当前")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            let cd = formattedCurrent(current)
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(cd.0)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                                Text(cd.1)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Progress bar
                if !isAchieved {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: min(progress, 1.0))
                            .tint(Color.formlogPrimary)
                            .frame(height: 10)
                            .scaleEffect(y: 1.4)
                            .animation(.easeOut(duration: 0.8), value: progress)

                        HStack {
                            Text("\(Int(min(progress, 1.0) * 100))%")
                                .font(.system(size: 12, design: .rounded).monospacedDigit())
                                .foregroundColor(.secondary)
                            Spacer()
                            if progress >= 0.8 && progress < 1.0 {
                                Text("马上就要达成了！💪")
                                    .font(.system(size: 11))
                                    .foregroundColor(.formlogPrimary)
                            }
                        }
                    }
                } else {
                    // Achieved celebration message
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("恭喜你达成了目标，继续保持良好的状态！")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(isAchieved ? Color.formlogDecrease.opacity(0.06) : Color.systemBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isAchieved ? Color.formlogDecrease.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("删除目标", systemImage: "trash")
            }
        }
        .alert("删除目标", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { goalStore.deleteGoal(id: goal.id) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除这个目标吗？")
        }
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

    private func formattedCurrent(_ val: Double) -> (String, String) {
        if goal.metricType == .weight || goal.metricType == .muscleMass {
            let d = appState.displayWeight(val)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", val), goal.metricType.unit)
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
            Form {
                Section("指标") {
                    Picker("追踪指标", selection: $selectedMetric) {
                        ForEach(appState.enabledMetrics) { m in
                            Label(m.displayName, systemImage: m.icon).tag(m)
                        }
                    }
                }

                Section("方向") {
                    Picker("目标方向", selection: $direction) {
                        ForEach([GoalModel.Direction.decrease, .increase, .maintain], id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                let unitStr = (selectedMetric == .weight || selectedMetric == .muscleMass)
                    ? appState.weightUnit.rawValue : selectedMetric.unit

                Section("目标值 (\(unitStr))") {
                    TextField("例如 70", text: $targetStr)
                        .keyboardType(.decimalPad)
                    if let current = entryStore.latestValue(for: selectedMetric) {
                        let disp = displayCurrent(current)
                        Text("当前：\(disp.0) \(disp.1)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { isPresented = false }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") { addGoal() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.formlogPrimary)
                }
            }
            .alert("输入有误", isPresented: $showError) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("请输入有效的目标值")
            }
            .onAppear {
                if let first = appState.enabledMetrics.first { selectedMetric = first }
            }
        }
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
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
