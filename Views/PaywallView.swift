// PaywallView.swift
// 付费墙 — 一次性买断

import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(LinearGradient.bodylogGradient)
                        Text("解锁 BodyLog Pro")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("用数据和照片，见证你的身体变化")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Features
                    VStack(spacing: 0) {
                        proFeatureRow(icon: "photo.stack", title: "形体照片对比", desc: "拍照记录，对比身形变化")
                        Divider().padding(.leading, 52)
                        proFeatureRow(icon: "arrow.down.doc.fill", title: "CSV 数据导出/导入", desc: "随时导出导入数据")
                        Divider().padding(.leading, 52)
                        proFeatureRow(icon: "bell.fill", title: "每日提醒", desc: "自定义时间提醒记录")
                        Divider().padding(.leading, 52)
                        proFeatureRow(icon: "target", title: "无限目标", desc: "设置任意数量的健康目标")
                    }
                    .background(Color.systemBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    // Error
                    if let err = purchaseManager.purchaseError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.bodylogDanger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Load Products Error
                    if let loadErr = purchaseManager.loadProductsError {
                        VStack(spacing: 8) {
                            Text(loadErr)
                                .font(.system(size: 13))
                                .foregroundColor(.bodylogDanger)
                                .multilineTextAlignment(.center)
                            Button(action: {
                                Task { await purchaseManager.retryLoadProducts() }
                            }) {
                                Text("重试")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.bodylogPrimary)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Buy button
                    VStack(spacing: 12) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            Task { await purchaseManager.purchasePro() }
                        }) {
                            HStack {
                                if purchaseManager.isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else if purchaseManager.isLoadingProducts {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("购买 \(purchaseManager.formattedPrice)")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(purchaseManager.isPurchasing || purchaseManager.isLoadingProducts ? Color.secondary : Color.bodylogPrimary)
                            .cornerRadius(14)
                        }
                        .disabled(!purchaseManager.canPurchase)

                        Button(action: {
                            Task { await purchaseManager.restorePurchases() }
                        }) {
                            Text("恢复购买")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    Text("一次购买，支持多设备登录同一 Apple ID 使用。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
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
                    }
                }
            }
        }
        .onChange(of: appState.isPro) { isPro in
            if isPro { isPresented = false }
        }
    }

    private func proFeatureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.bodylogPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.bodylogPrimary)
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
