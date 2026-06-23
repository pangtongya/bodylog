import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var isPresented: Bool

    @State private var showPulse = false
    @State private var animateFeatures = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.bottom, 24)

                    featuresSection
                        .padding(.bottom, 24)
                        .opacity(animateFeatures ? 1 : 0)
                        .offset(y: animateFeatures ? 0 : 20)

                    pricingSection
                        .padding(.bottom, 20)

                    trustBadges
                        .padding(.bottom, 16)

                    actionButtons
                        .padding(.bottom, 12)

                    legalFooter
                        .padding(.bottom, 20)
                }
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 22))
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    animateFeatures = true
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    showPulse = true
                }
            }
            .onChange(of: appState.isPro) { isPro in
                if isPro { isPresented = false }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.formlogGradient.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(showPulse ? 1.15 : 1.0)

                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(LinearGradient.formlogGradient)
            }
            .padding(.top, 16)

            VStack(spacing: 6) {
                Text(L10n.string("升级到 FormLog Pro"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(L10n.string("开启完整的身体记录体验"))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                statBadge(value: "12+", label: L10n.string("种指标"))
                Divider()
                    .frame(height: 32)
                statBadge(value: "∞", label: L10n.string("目标数量"))
                Divider()
                    .frame(height: 32)
                statBadge(value: "100%", label: L10n.string("隐私安全"))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient.formlogGradient)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: L10n.string("Pro 专属功能"))

            VStack(spacing: 0) {
                featureRow(
                    icon: "camera.viewfinder",
                    title: L10n.string("形体照片记录"),
                    desc: L10n.string("拍照记录身体变化，对比功能一目了然"),
                    highlight: true
                )
                Divider().padding(.leading, 64)

                featureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: L10n.string("深度趋势分析"),
                    desc: L10n.string("多维度数据洞察，智能分析你的进度"),
                    highlight: true
                )
                Divider().padding(.leading, 64)

                featureRow(
                    icon: "target",
                    title: L10n.string("无限目标设定"),
                    desc: L10n.string("为每个指标设立目标，追踪达成进度"),
                    highlight: false
                )
                Divider().padding(.leading, 64)

                featureRow(
                    icon: "bell.badge.fill",
                    title: L10n.string("智能每日提醒"),
                    desc: L10n.string("自定义提醒时间，不再错过记录"),
                    highlight: false
                )
                Divider().padding(.leading, 64)

                featureRow(
                    icon: "square.and.arrow.up",
                    title: L10n.string("数据导出导入"),
                    desc: L10n.string("支持 CSV 格式，数据永远属于你"),
                    highlight: false
                )
                Divider().padding(.leading, 64)

                featureRow(
                    icon: "photo.artframe",
                    title: L10n.string("分享卡片生成"),
                    desc: L10n.string("一键生成精美分享图，记录你的蜕变"),
                    highlight: false
                )
                Divider().padding(.leading, 64)

                featureRow(
                    icon: "trophy",
                    title: L10n.string("成就系统"),
                    desc: L10n.string("解锁专属成就，保持记录动力"),
                    highlight: false
                )
            }
            .background(Color.systemBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
    }

    private func featureRow(icon: String, title: String, desc: String, highlight: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(highlight ? LinearGradient.formlogGradient : Color.formlogPrimary.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(highlight ? .white : .formlogPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.formlogPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if let err = purchaseManager.purchaseError {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.formlogDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let loadErr = purchaseManager.loadProductsError {
                VStack(spacing: 12) {
                    Label(loadErr, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.formlogDanger)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await purchaseManager.retryLoadProducts() }
                    }) {
                        Label(L10n.string("重新加载"), systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(Color.formlogPrimary)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
            }

            if purchaseManager.loadProductsError == nil {
                pricingCard
            }
        }
    }

    private var pricingCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("一次性买断"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(purchaseManager.formattedPrice)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient.formlogGradient)

                        Text(L10n.string("永久使用"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Text(L10n.string("限时优惠"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.formlogDanger)
                        .cornerRadius(6)

                    Text(L10n.string("无订阅 · 无广告"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LinearGradient.formlogGradient, lineWidth: 1.5)
                .opacity(0.6)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Trust Badges

    private var trustBadges: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                trustBadge(icon: "lock.shield.fill", text: L10n.string("隐私优先"))
                trustBadge(icon: "icloud.fill", text: L10n.string("本地存储"))
                trustBadge(icon: "infinity", text: L10n.string("终身使用"))
                trustBadge(icon: "applelogo", text: L10n.string("Apple 支付"))
            }
        }
        .padding(.horizontal, 20)
    }

    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.formlogPrimary)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                Task { await purchaseManager.purchasePro() }
            }) {
                HStack {
                    Spacer()
                    if purchaseManager.isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text(L10n.string("处理中..."))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else if purchaseManager.isLoadingProducts {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text(L10n.string("立即解锁 Pro"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(height: 56)
                .background(
                    LinearGradient.formlogGradient
                        .opacity(purchaseManager.canPurchase && !purchaseManager.isPurchasing ? 1 : 0.5)
                )
                .cornerRadius(16)
                .shadow(color: .formlogPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(!purchaseManager.canPurchase || purchaseManager.isPurchasing)
            .padding(.horizontal, 16)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await purchaseManager.restorePurchases() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                    Text(L10n.string("已有 Pro？恢复购买"))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.formlogPrimary)
            }

            Button(action: { isPresented = false }) {
                Text(L10n.string("先看看免费版"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .underline()
            }
        }
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                if let termsURL = URL(string: "https://pangtongya.github.io/formlog-privacy/terms.html") {
                    Link(L10n.string("服务条款"), destination: termsURL)
                }

                Text("·")
                    .foregroundColor(.tertiaryLabel)

                if let privacyURL = URL(string: "https://pangtongya.github.io/formlog-privacy/privacy-policy.html") {
                    Link(L10n.string("隐私政策"), destination: privacyURL)
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            Text(L10n.string("由 Apple App Store 安全处理支付"))
                .font(.system(size: 10))
                .foregroundColor(.tertiaryLabel)
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

#Preview {
    PaywallView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
        .environmentObject(PurchaseManager.shared)
}
