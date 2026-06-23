import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState

    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var heightStr: String = ""
    @State private var gender: AppState.Gender = .notSet
    @State private var weightUnit: AppState.WeightUnit = .kg
    @State private var selectedMetrics: Set<BodyMetricType> = [.weight, .bodyFat]
    @State private var hasGoal: Bool = true
    @State private var goalType: GoalType = .loseWeight
    @State private var goalWeightStr: String = ""
    @State private var showPulse = false

    private let totalSteps = 4

    private enum GoalType: String, CaseIterable {
        case loseWeight = "loseWeight"
        case gainMuscle = "gainMuscle"
        case maintain = "maintain"
        case trackOnly = "trackOnly"

        var displayName: String {
            switch self {
            case .loseWeight: return L10n.string("减脂减重")
            case .gainMuscle: return L10n.string("增肌塑形")
            case .maintain: return L10n.string("保持身材")
            case .trackOnly: return L10n.string("只是记录")
            }
        }

        var icon: String {
            switch self {
            case .loseWeight: return "scalemass"
            case .gainMuscle: return "dumbbell.fill"
            case .maintain: return "heart.fill"
            case .trackOnly: return "chart.bar.doc.horizontal"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.systemBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= step ? Color.formlogPrimary : Color.systemGray4)
                            .frame(width: i == step ? 10 : 6, height: i == step ? 10 : 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
                    }
                }
                .padding(.top, 52)

                if step < totalSteps - 1 {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { step = totalSteps - 1 }
                    }) {
                        Text(L10n.string("跳过"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)
                }

                Spacer()

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: profileStep
                    case 2: metricsStep
                    case 3: goalStep
                    default: welcomeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                VStack(spacing: 12) {
                    Button(action: nextStep) {
                        HStack {
                            Text(step == totalSteps - 1 ? L10n.string("开启记录之旅") : L10n.string("下一步"))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Image(systemName: step == totalSteps - 1 ? "sparkles" : "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient.formlogGradient)
                        .cornerRadius(16)
                        .shadow(color: .formlogPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .padding(.horizontal, 24)

                    if step > 0 {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation { step -= 1 }
                        }) {
                            Text(L10n.string("上一步"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showPulse = true
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(LinearGradient.formlogGradient.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .scaleEffect(showPulse ? 1.1 : 1.0)

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(LinearGradient.formlogGradient)
            }
            .padding(.bottom, 4)

            VStack(spacing: 14) {
                Text(L10n.string("欢迎来到 FormLog"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text(L10n.string("记录每一次改变\n见证你的蜕变"))
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                featureCard(icon: "camera.fill", title: L10n.string("照片记录"), desc: L10n.string("拍照对比，直观看到变化"))
                featureCard(icon: "chart.line.uptrend.xyaxis", title: L10n.string("数据追踪"), desc: L10n.string("12种指标，全面记录身体数据"))
                featureCard(icon: "lock.shield.fill", title: L10n.string("隐私安全"), desc: L10n.string("数据本地存储，隐私优先"))
            }
            .padding(.horizontal, 28)
        }
        .padding(.horizontal, 20)
    }

    private func featureCard(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.formlogPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var profileStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(L10n.string("了解一下你"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(L10n.string("帮助你更精准地记录"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.string("你的名字"), systemImage: "person.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField(L10n.string("昵称（选填）"), text: $name)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(Color.systemGray6)
                        .cornerRadius(12)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.string("身高"), systemImage: "ruler.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField(L10n.string("cm"), text: $heightStr)
                            .font(.system(size: 16))
                            .keyboardType(.decimalPad)
                            .padding(14)
                            .background(Color.systemGray6)
                            .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.string("单位"), systemImage: "scalemass.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $weightUnit) {
                            ForEach(AppState.WeightUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(4)
                        .background(Color.systemGray6)
                        .cornerRadius(12)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.string("性别"), systemImage: "person.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        ForEach(AppState.Gender.allCases, id: \.self) { g in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                gender = g
                            }) {
                                Text(g.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(gender == g ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(gender == g ? Color.formlogPrimary : Color.systemGray6)
                                    .cornerRadius(12)
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
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(L10n.string("选择要追踪的指标"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(L10n.string("至少选择一个，之后可随时修改"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach([BodyMetricType.MetricCategory.primary, .measurement], id: \.rawValue) { category in
                        let metrics = BodyMetricType.allCases.filter { $0.category == category }
                        Section {
                            ForEach(metrics) { metric in
                                metricToggleRow(metric)
                                if metric.id != metrics.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        } header: {
                            Text(category.localizedName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 6)
                        }
                    }
                }
                .background(Color.systemGray6)
                .cornerRadius(14)
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: 380)
        }
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
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.formlogPrimary.opacity(0.15) : Color.clear)
                        .frame(width: 36, height: 36)

                    Image(systemName: metric.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .formlogPrimary : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.displayName)
                        .font(.system(size: 15))
                    if !metric.unit.isEmpty {
                        Text("(\(metric.unit))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .formlogPrimary : .systemGray3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.formlogPrimary.opacity(0.04) : Color.clear)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private var goalStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(L10n.string("设定一个目标"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(L10n.string("有目标才更有动力 💪"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(GoalType.allCases, id: \.self) { goal in
                    goalOptionRow(goal)
                }
            }
            .padding(.horizontal, 16)

            if hasGoal && (goalType == .loseWeight || goalType == .gainMuscle) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("目标体重 (\(weightUnit.rawValue))")
                    } icon: {
                        Image(systemName: "target")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    TextField(L10n.string("例如：65"), text: $goalWeightStr)
                        .font(.system(size: 16))
                        .keyboardType(.decimalPad)
                        .padding(14)
                        .background(Color.systemGray6)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private func goalOptionRow(_ goal: GoalType) -> some View {
        let isSelected = (goalType == goal)
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            goalType = goal
            hasGoal = goal != .trackOnly
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? LinearGradient.formlogGradient : Color.systemGray6)
                        .frame(width: 44, height: 44)

                    Image(systemName: goal.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .formlogPrimary)
                }

                Text(goal.displayName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .formlogPrimary : .systemGray3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.formlogPrimary.opacity(0.3) : Color.clear, lineWidth: 2)
                    .background(Color.systemBackground)
            )
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private func nextStep() {
        UIImpactFeedbackGenerator(style: step == totalSteps - 1 ? .heavy : .medium).impactOccurred()
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            appState.userName = name
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
