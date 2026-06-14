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
                            .padding(.horizontal, 20)
                            .padding(.top, 40)
                    } else {
                        // Active Goals
                        if !goalStore.activeGoals.isEmpty {
                            sectionHeader("进行中的目标")
                                .padding(.horizontal, 20)
                            ForEach(goalStore.activeGoals) { goal in
                                GoalCardView(goal: goal)
                                    .padding(.horizontal, 20)
                            }
                        }

                        // Achieved Goals
                        if !goalStore.achievedGoals.isEmpty {
                            sectionHeader("已达成")
                                .padding(.horizontal, 20)
                            ForEach(goalStore.achievedGoals) { goal in
                                GoalCardView(goal: goal, isAchieved: true)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
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
                        .foregroundColor(.bodylogPrimary)
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
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 56))
                .foregroundColor(.bodylogPrimary.opacity(0.4))
            Text("还没有设置目标")
                .font(.system(size: 18, weight: .semibold))
            Text("设定一个减重、减脂或增肌目标\n每次记录后自动追踪进度")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            Button(action: { showAddGoal = true }) {
                Text("设置目标")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.bodylogPrimary)
                    .cornerRadius(20)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
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

    private var currentValue: Double? { entryStore.latestValue(for: goal.metricType) }
    private var startValue: Double? { entryStore.startValue(for: goal.metricType) }

    private var progress: Double {
        guard let current = currentValue, let start = startValue else { return 0 }
        return goal.progress(currentValue: current, startValue: start)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: goal.metricType.icon)
                    .foregroundColor(isAchieved ? .bodylogDecrease : .bodylogPrimary)
                Text(goal.metricType.displayName)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if isAchieved {
                    Label("已达成", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.bodylogDecrease)
                } else {
                    Image(systemName: goal.direction.icon)
                        .foregroundColor(.bodylogPrimary.opacity(0.7))
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
                    .foregroundColor(isAchieved ? .bodylogDecrease : .bodylogPrimary)
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
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.systemGray5)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.bodylogPrimary)
                                .frame(width: geo.size.width * progress, height: 8)
                                .animation(.easeOut(duration: 0.8), value: progress)
                        }
                    }
                    .frame(height: 8)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, design: .rounded).monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(isAchieved ? Color.bodylogDecrease.opacity(0.06) : Color.systemBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isAchieved ? Color.bodylogDecrease.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 1)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { showDeleteAlert = true } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .alert("删除目标", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { goalStore.deleteGoal(id: goal.id) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除这个目标吗？")
        }
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
                        .foregroundColor(.bodylogPrimary)
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
