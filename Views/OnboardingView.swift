// OnboardingView.swift
// Premium Apple HIG-style onboarding flow

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var heightStr: String = ""
    @State private var gender: AppState.Gender = .notSet
    @State private var weightUnit: AppState.WeightUnit = .kg
    @State private var selectedMetrics: Set<BodyMetricType> = [.weight, .bodyFat]
    @State private var isPulsing: Bool = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            Color.formlogBgGrouped.ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }

            VStack(spacing: 0) {
                // Navigation / skip / progress area
                navHeader

                // Step content (fills remaining space)
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

                // Bottom CTA
                bottomCTA
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    // MARK: - Navigation Header

    private var navHeader: some View {
        VStack(spacing: 0) {
            if step > 0 {
                // Back button + progress dots for steps 2 & 3
                HStack(alignment: .center) {
                    Button(action: { withAnimation { step -= 1 } }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text(L10n.string("返回"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.formlogPrimary)
                    }

                    Spacer()

                    progressDots
                }
                .padding(.horizontal, .spacing2Xl)
                .padding(.top, 12)
                .padding(.bottom, .spacingMd)
            } else {
                // Skip button (top right) + progress dots for step 1
                HStack(alignment: .center) {
                    Spacer()
                    Button(action: skipOnboarding) {
                        Text(L10n.string("跳过"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.formlogTextSecondary)
                    }
                }
                .padding(.horizontal, .spacing2Xl)
                .padding(.top, 12)

                progressDots
                    .padding(.top, 12)
                    .padding(.bottom, .spacingMd)
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i <= step ? Color.formlogPrimary : Color.formlogFillTertiary)
                    .frame(width: i == step ? 10 : 6, height: i == step ? 10 : 6)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Button(action: nextStep) {
                HStack(spacing: 8) {
                    Text(step == totalSteps - 1 ? L10n.string("开始记录") : L10n.string("下一步"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if step == totalSteps - 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.formlogPrimary)
                .clipShape(RoundedRectangle(cornerRadius: .radiusLg))
            }
            .padding(.horizontal, .spacing2Xl)
            .padding(.bottom, .spacing5Xl)
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Hero icon with pulsing animation
                ZStack {
                    Circle()
                        .fill(Color.formlogPrimaryPale)
                        .frame(width: 120, height: 120)
                        .scaleEffect(isPulsing ? 1.08 : 1.0)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 52, weight: .light))
                        .foregroundColor(.formlogPrimary)
                        .scaleEffect(isPulsing ? 1.04 : 1.0)
                }
                .padding(.top, .spacing2Xl)
                .padding(.bottom, .spacing2Xl)

                // Headline
                Text(L10n.string("你的身体变化\n值得被记录"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.formlogTextPrimary)
                    .tracking(-0.5)
                    .padding(.bottom, .spacingMd)

                // Differentiator cards
                VStack(spacing: .spacingSm) {
                    differentiatorRow(
                        icon: "lock.shield",
                        title: L10n.string("隐私优先"),
                        subtitle: L10n.string("数据只存在你的手机，不上云")
                    )
                    Divider()
                        .padding(.leading, 56)
                    differentiatorRow(
                        icon: "creditcard",
                        title: L10n.string("一次买断"),
                        subtitle: L10n.string("没有订阅，永久使用")
                    )
                    Divider()
                        .padding(.leading, 56)
                    differentiatorRow(
                        icon: "photo.stack",
                        title: L10n.string("照片对比"),
                        subtitle: L10n.string("见证形体变化（独家功能）")
                    )
                    Divider()
                        .padding(.leading, 56)
                    differentiatorRow(
                        icon: "chart.line.flattrend.xyaxis",
                        title: L10n.string("智能洞察"),
                        subtitle: L10n.string("自动分析你的变化趋势")
                    )
                }
                .padding(.horizontal, .spacingXl)
                .padding(.vertical, .spacingSm)
                .background(Color.formlogCard)
                .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                .overlay(
                    RoundedRectangle(cornerRadius: .radiusXl)
                        .stroke(Color.formlogSeparator, lineWidth: 0.5)
                )
                .padding(.horizontal, .spacing2Xl)

                Spacer(minLength: 40)
            }
        }
    }

    private func differentiatorRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: .spacingMd) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.formlogPrimary)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.formlogTextPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.formlogTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, .spacingMd)
        .padding(.vertical, .spacingSm)
    }

    // MARK: - Step 2: Profile

    private var profileStep: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: .spacing2Xl) {
                // Title
                Text(L10n.string("填写基本信息"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.formlogTextPrimary)
                    .tracking(-0.3)
                    .padding(.bottom, .spacingXs)

                // Name
                VStack(alignment: .leading, spacing: .spacingSm) {
                    Text(L10n.string("你的名字（可选）"))
                        .font(.blSubheadSemibold)
                        .foregroundColor(.formlogTextSecondary)
                    TextField(L10n.string("昵称"), text: $name)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(Color.formlogCard)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusMd)
                                .stroke(Color.formlogSeparator, lineWidth: 0.5)
                        )
                }

                // Height
                VStack(alignment: .leading, spacing: .spacingSm) {
                    Text(L10n.string("身高（cm）"))
                        .font(.blSubheadSemibold)
                        .foregroundColor(.formlogTextSecondary)
                    TextField(L10n.string("例如：175"), text: $heightStr)
                        .font(.system(size: 16))
                        .keyboardType(.decimalPad)
                        .padding(14)
                        .background(Color.formlogCard)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusMd)
                                .stroke(Color.formlogSeparator, lineWidth: 0.5)
                        )
                }

                // Gender pills
                VStack(alignment: .leading, spacing: .spacingSm) {
                    Text(L10n.string("性别"))
                        .font(.blSubheadSemibold)
                        .foregroundColor(.formlogTextSecondary)
                    HStack(spacing: .spacingSm) {
                        ForEach(AppState.Gender.allCases, id: \.self) { g in
                            Button(action: {
                                BodyLogHaptics.light()
                                gender = g
                            }) {
                                Text(g.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(gender == g ? .white : .formlogTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(gender == g ? Color.formlogPrimary : Color.formlogCard)
                                    .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: .radiusMd)
                                            .stroke(
                                                gender == g ? Color.formlogPrimary : Color.formlogSeparator,
                                                lineWidth: gender == g ? 0 : 0.5
                                            )
                                    )
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }

                // Weight unit pills
                VStack(alignment: .leading, spacing: .spacingSm) {
                    Text(L10n.string("重量单位"))
                        .font(.blSubheadSemibold)
                        .foregroundColor(.formlogTextSecondary)
                    HStack(spacing: .spacingSm) {
                        ForEach(AppState.WeightUnit.allCases, id: \.self) { u in
                            Button(action: {
                                BodyLogHaptics.light()
                                weightUnit = u
                            }) {
                                Text(u.rawValue)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(weightUnit == u ? .white : .formlogTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(weightUnit == u ? Color.formlogPrimary : Color.formlogCard)
                                    .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: .radiusMd)
                                            .stroke(
                                                weightUnit == u ? Color.formlogPrimary : Color.formlogSeparator,
                                                lineWidth: weightUnit == u ? 0 : 0.5
                                            )
                                    )
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .padding(.horizontal, .spacing2Xl)
            .padding(.top, .spacingMd)
            .padding(.bottom, .spacing3Xl)
        }
    }

    // MARK: - Step 3: Metrics

    private var metricsStep: some View {
        VStack(spacing: 0) {
            // Title
            VStack(spacing: .spacingSm) {
                Text(L10n.string("选择要追踪的指标"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.formlogTextPrimary)
                    .tracking(-0.3)
                Text(L10n.string("至少选择一个，之后可以在设置中修改"))
                    .font(.system(size: 14))
                    .foregroundColor(.formlogTextSecondary)
            }
            .padding(.horizontal, .spacing2Xl)
            .padding(.top, .spacingMd)
            .padding(.bottom, .spacingLg)

            // Metrics list in a grouped card
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach([BodyMetricType.MetricCategory.primary, .measurement], id: \.rawValue) { category in
                        let metrics = BodyMetricType.allCases.filter { $0.category == category }

                        // Section header
                        HStack {
                            Text(category.localizedName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.formlogTextSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, .spacing2Xl)
                        .padding(.top, .spacingLg)
                        .padding(.bottom, .spacingSm)

                        // Metrics card
                        VStack(spacing: 0) {
                            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                                metricToggleRow(metric)
                                if index < metrics.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color.formlogCard)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusXl)
                                .stroke(Color.formlogSeparator, lineWidth: 0.5)
                        )
                        .padding(.horizontal, .spacing2Xl)
                    }
                }
                .padding(.bottom, .spacing3Xl)
            }
        }
    }

    private func metricToggleRow(_ metric: BodyMetricType) -> some View {
        let isSelected = selectedMetrics.contains(metric)
        return Button(action: {
            BodyLogHaptics.light()
            if isSelected {
                if selectedMetrics.count > 1 { selectedMetrics.remove(metric) }
            } else {
                selectedMetrics.insert(metric)
            }
        }) {
            HStack(spacing: .spacingMd) {
                // Metric icon circle
                ZStack {
                    Circle()
                        .fill(metric.color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: metric.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(metric.color)
                }

                // Label
                Text(metric.displayName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.formlogTextPrimary)

                // Unit badge
                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.formlogTextTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.formlogFillTertiary)
                        .clipShape(Capsule())
                }

                Spacer()

                // Checkmark circle
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .formlogPrimary : .formlogFillTertiary)
            }
            .padding(.horizontal, .spacingLg)
            .padding(.vertical, .spacingSm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func skipOnboarding() {
        appState.enabledMetrics = [.weight, .bodyFat]
        appState.weightUnit = .kg
        appState.userName = ""
        appState.hasCompletedOnboarding = true
        _ = appState.validateAllMetrics()
        appState.save()
        BodyLogHaptics.light()
    }

    private func nextStep() {
        BodyLogHaptics.heavy()
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            // Save and complete onboarding
            appState.userName = name
            // Height validation: normal adult range 100-250cm
            if let h = Double(heightStr), h >= 100 && h <= 250 {
                appState.userHeight = h
            } else {
                appState.userHeight = 170.0
            }
            appState.userGender = gender
            appState.weightUnit = weightUnit
            appState.enabledMetrics = Array(selectedMetrics)
            appState.hasCompletedOnboarding = true
            appState.save()
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState.shared)
}
