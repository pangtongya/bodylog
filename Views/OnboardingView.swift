// OnboardingView.swift
// 引导流程（填写基本信息）

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var heightStr: String = ""
    @State private var birthYear: Int = Calendar.current.component(.year, from: Date()) - 25
    @State private var gender: AppState.Gender = .notSet
    @State private var weightUnit: AppState.WeightUnit = .kg
    @State private var selectedMetrics: Set<BodyMetricType> = [.weight, .bodyFat]

    private let totalSteps = 3

    var body: some View {
        ZStack {
            Color.systemBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= step ? Color.bodylogPrimary : Color.systemGray4)
                            .frame(width: i == step ? 10 : 6, height: i == step ? 10 : 6)
                            .animation(.spring(), value: step)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Step content
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: profileStep
                    case 2: metricsStep
                    default: welcomeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // CTA
                Button(action: nextStep) {
                    HStack {
                        Text(step == totalSteps - 1 ? "开始记录" : "下一步")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Image(systemName: step == totalSteps - 1 ? "checkmark" : "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.bodylogPrimary)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.stand")
                .font(.system(size: 72))
                .foregroundColor(.bodylogPrimary)
                .padding(.bottom, 8)

            Text("你的身体变化\n值得被记录")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("用数据和照片，见证每一次进步")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("不同于 Apple 健康 · 隐私优先 · 一次买断")
                .font(.system(size: 16))
                .foregroundColor(.bodylogPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            // Value proposition
            VStack(alignment: .leading, spacing: 16) {
                featureBullet(icon: "lock.shield.fill", text: "隐私优先 - 数据只存在你的手机，不上云")
                featureBullet(icon: "creditcard.fill", text: "¥6 买断 - 没有订阅，永久使用")
                featureBullet(icon: "photo.stack.fill", text: "照片对比 - 见证形体变化（独家）")
                featureBullet(icon: "chart.line.uptrend.xyaxis", text: "智能洞察 - 自动分析你的变化趋势")
            }
            .padding(.horizontal, 32)
        }
        .padding(.horizontal, 24)
    }

    private var profileStep: some View {
        VStack(spacing: 28) {
            Text("填写基本信息")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            VStack(spacing: 20) {
                // 姓名
                VStack(alignment: .leading, spacing: 8) {
                    Label("你的名字（可选）", systemImage: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("昵称", text: $name)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Color.systemGray6)
                        .cornerRadius(10)
                }

                // 身高
                VStack(alignment: .leading, spacing: 8) {
                    Label("身高（cm）", systemImage: "ruler.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("例如：175", text: $heightStr)
                        .font(.system(size: 16))
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color.systemGray6)
                        .cornerRadius(10)
                }

                // 性别
                VStack(alignment: .leading, spacing: 8) {
                    Label("性别", systemImage: "person.2.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        ForEach(AppState.Gender.allCases, id: \.self) { g in
                            Button(action: { gender = g }) {
                                Text(g.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(gender == g ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(gender == g ? Color.bodylogPrimary : Color.systemGray6)
                                    .cornerRadius(10)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }

                // 重量单位
                VStack(alignment: .leading, spacing: 8) {
                    Label("重量单位", systemImage: "scalemass.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        ForEach(AppState.WeightUnit.allCases, id: \.self) { u in
                            Button(action: { weightUnit = u }) {
                                Text(u.rawValue)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(weightUnit == u ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(weightUnit == u ? Color.bodylogPrimary : Color.systemGray6)
                                    .cornerRadius(10)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var metricsStep: some View {
        VStack(spacing: 24) {
            Text("选择要追踪的指标")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("至少选择一个，之后可以在设置中修改")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach([BodyMetricType.MetricCategory.primary, .measurement], id: \.rawValue) { category in
                        let metrics = BodyMetricType.allCases.filter { $0.category == category }
                        Section {
                            ForEach(metrics) { metric in
                                metricToggleRow(metric)
                            }
                        } header: {
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                        }
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .padding(.horizontal, 8)
    }

    private func metricToggleRow(_ metric: BodyMetricType) -> some View {
        let isSelected = selectedMetrics.contains(metric)
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelected {
                if selectedMetrics.count > 1 { selectedMetrics.remove(metric) }
            } else {
                selectedMetrics.insert(metric)
            }
        }) {
            HStack {
                Image(systemName: metric.icon)
                    .foregroundColor(isSelected ? .bodylogPrimary : .secondary)
                    .frame(width: 28)
                Text(metric.displayName)
                    .font(.system(size: 15))
                if !metric.unit.isEmpty {
                    Text("(\(metric.unit))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .bodylogPrimary : .systemGray3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func nextStep() {
        UIImpactFeedbackGenerator(style: step == totalSteps - 1 ? .heavy : .medium).impactOccurred()
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            // Save and complete onboarding
            appState.userName = name
            if let h = Double(heightStr), h > 0 { appState.userHeight = h }
            appState.userGender = gender
            appState.weightUnit = weightUnit
            appState.enabledMetrics = Array(selectedMetrics)
            appState.hasCompletedOnboarding = true
            appState.save()
        }
    }

    private func featureBullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.bodylogPrimary)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState.shared)
}
