// PaywallView.swift
// 付费墙 — 一次性买断 Pro 版本

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Spacer for close button ──
                    Color.clear.frame(height: 8)

                    // ── Crown hero ──
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.formlogPrimaryPale)
                                .frame(width: 80, height: 80)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color.formlogPrimary)
                        }

                        Text(L10n.string("解锁 Pro 版本"))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.formlogTextPrimary)

                        Text(L10n.string("用数据和照片，见证你的身体变化"))
                            .font(.system(size: 15))
                            .foregroundColor(.formlogTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // ── Features card (emotionally ordered) ──
                    VStack(spacing: 0) {
                        proFeatureRow(icon: "photo.compare", title: L10n.string("形体照片对比"), desc: L10n.string("看到两周前的自己，对比今天的改变"))
                        featureSeparator
                        proFeatureRow(icon: "bell.fill", title: L10n.string("每日提醒"), desc: L10n.string("再也不会忘记记录，养成习惯就这么简单"))
                        featureSeparator
                        proFeatureRow(icon: "target", title: L10n.string("无限目标"), desc: L10n.string("体重、体脂、腰围……同时追踪所有目标"))
                        featureSeparator
                        proFeatureRow(icon: "arrow.down.doc", title: L10n.string("CSV 数据导出导入"), desc: L10n.string("你的数据永远属于你，随时可以带走"))
                    }
                    .background(Color.formlogCard)
                    .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                    .padding(.horizontal, 16)
                    .padding(.top, 28)

                    // ── Error: purchase ──
                    if let err = purchaseManager.purchaseError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.formlogDanger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 16)
                    }

                    // ── Error: load products ──
                    if let loadErr = purchaseManager.loadProductsError {
                        VStack(spacing: 12) {
                            Label(loadErr, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.formlogDanger)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                BodyLogHaptics.medium()
                                Task { await purchaseManager.retryLoadProducts() }
                            }) {
                                Label(L10n.string("重试加载"), systemImage: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.formlogPrimary)
                                    .cornerRadius(.radiusSm)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                    }

                    // ── Trust badge ──
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 13))
                            .foregroundColor(.formlogTextSecondary)
                        Text(L10n.string("隐私优先 · 数据本地 · 一次买断"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.formlogTextSecondary)
                    }
                    .padding(.top, 28)

                    // ── Social proof ──
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.formlogPrimary)
                        Text(L10n.string("已有用户坚持记录 100+ 天"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.formlogTextSecondary)
                    }
                    .padding(.top, 8)

                    // ── Price anchoring + CTA ──
                    VStack(spacing: 16) {
                        // Comparison line (price anchoring)
                        Text(L10n.string("同类 App 每月 ¥18-28，FormLog 一次买断永久使用"))
                            .font(.system(size: 13))
                            .foregroundColor(.formlogTextSecondary)
                            .multilineTextAlignment(.center)

                        VStack(spacing: 6) {
                            Text(purchaseManager.formattedPrice)
                                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundColor(.formlogTextPrimary)
                            Text(L10n.string("一次性购买 · 永久使用"))
                                .font(.system(size: 14))
                                .foregroundColor(.formlogTextSecondary)
                            // Price anchor subtitle
                            Text(L10n.string("≈ 一杯奶茶的价格 · 终身使用"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.formlogPrimary)
                        }

                        Button(action: {
                            BodyLogHaptics.heavy()
                            Task { await purchaseManager.purchasePro() }
                        }) {
                            HStack(spacing: 8) {
                                if purchaseManager.isPurchasing || purchaseManager.isLoadingProducts {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(L10n.string("立即解锁 · 一次买断"))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(purchaseManager.isPurchasing || purchaseManager.isLoadingProducts ? Color.formlogFillTertiary : Color.formlogPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: .radiusLg))
                        }
                        .disabled(!purchaseManager.canPurchase)

                        Button(action: {
                            Task { await purchaseManager.restorePurchases() }
                        }) {
                            Text(L10n.string("恢复购买"))
                                .font(.system(size: 14))
                                .foregroundColor(.formlogTextSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28)

                    // ── Legal links ──
                    if let privacyURL = URL(string: "https://pangtongya.github.io/bodylog/privacy.html") {
                        Link(L10n.string("隐私政策"), destination: privacyURL)
                            .font(.system(size: 12))
                            .foregroundColor(.formlogTextSecondary)
                            .padding(.top, 24)
                            .padding(.bottom, 20)
                    }
                }
            }
            .background(Color.formlogBgGrouped)
            .ignoresSafeArea()

            // ── Close button (overlay) ──
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 28, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.formlogFillSecondary)
            }
            .accessibilityLabel(L10n.string("关闭"))
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
        .onChange(of: appState.isPro) { isPro in
            if isPro { isPresented = false }
        }
    }

    // MARK: - Subviews

    private var featureSeparator: some View {
        Divider()
            .foregroundStyle(Color.formlogSeparator)
            .padding(.leading, 52)
    }

    private func proFeatureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.formlogPrimaryPale)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color.formlogPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.formlogTextPrimary)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.formlogTextSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.formlogPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    PaywallView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
        .environmentObject(PurchaseManager.shared)
}
