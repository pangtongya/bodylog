// ShareCardView.swift
// 数据分享卡片 - 生成可分享的图片

import SwiftUI

struct ShareCardView: View {
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: Image?
    @State private var shareItems: [Any] = []
    @State private var showShareSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview card
                    shareCardPreview
                        .padding(.horizontal, 20)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle(L10n.string("分享进度"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
                    .onDisappear { showShareSheet = false; shareItems = [] }
            }
        }
    }
    
    // MARK: - App Name (from InfoPlist)
    
    private var appDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "FormLog"
    }

    // MARK: - Card Preview

    private var shareCardPreview: some View {
        VStack(spacing: 0) {
            // Card content (will be captured as image)
            cardContent
                // 强制浅色模式：分享卡片始终白底黑字，确保深色模式下文字可见
                .environment(\.colorScheme, .light)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        }
    }

    private var cardContent: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appDisplayName)
                        .font(.system(size: 18, weight: .bold))
                    Text(formatDate(Date()))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "figure.stand")
                    .font(.system(size: 28))
                    .foregroundColor(.formlogPrimary)
            }

            Divider()

            // Stats grid
            HStack(spacing: 16) {
                statItem(
                    value: "\(entryStore.totalRecordDays)",
                    label: L10n.string("记录天数"),
                    icon: "calendar"
                )
                statItem(
                    value: "\(entryStore.currentStreak)",
                    label: L10n.string("连续天数"),
                    icon: "flame.fill"
                )
                statItem(
                    value: "\(entryStore.entries.count)",
                    label: L10n.string("总记录"),
                    icon: "chart.bar.fill"
                )
            }

            // Latest metrics (if available)
            if let latest = entryStore.latestEntry, latest.hasAnyMetric {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("最近记录"))
                        .font(.system(size: 14, weight: .semibold))

                    let displayMetrics = Array(latest.metrics.prefix(4))
                    ForEach(displayMetrics, id: \.key) { key, value in
                        if let type = BodyMetricType(rawValue: key) {
                            HStack {
                                Image(systemName: type.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.formlogPrimary)
                                    .frame(width: 20)
                                Text(type.displayName)
                                    .font(.system(size: 14))
                                Spacer()
                                if type == .weight || type == .muscleMass {
                                    let d = appState.displayWeight(value)
                                    Text("\(String(format: "%.1f", d.value)) \(d.unit)")
                                        .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                                } else {
                                    Text("\(String(format: "%.1f", value)) \(type.unit)")
                                        .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                                }
                            }
                        }
                    }
                }
            }

            // Footer
            Divider()

            HStack {
                Text(L10n.string("🔒 隐私优先 · 数据本地存储"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Text(appDisplayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
            }
        }
        .padding(24)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.formlogPrimary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Share button
            Button(action: generateAndShare) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.string("分享这张卡片"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.formlogPrimary)
                .cornerRadius(12)
            }

            // Save to photos button
            Button(action: saveToPhotos) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text(L10n.string("保存到相册"))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                }
                .foregroundColor(.formlogPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.formlogPrimary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Actions

    private func generateAndShare() {
        if let image = renderAsImage() {
            shareItems = [image]
            showShareSheet = true
        }
    }

    private func saveToPhotos() {
        guard let image = renderAsImage() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    private func renderAsImage() -> UIImage? {
        let controller = UIHostingController(rootView:
            cardContent
                .frame(width: 350)
                .environment(\.colorScheme, .light)
        )
        let view = controller.view

        view?.backgroundColor = .white
        // 先设置宽度，让 SwiftUI 自适应计算高度
        view?.frame = CGRect(x: 0, y: 0, width: 350, height: 0)
        let targetSize = controller.sizeThatFits(in: CGSize(width: 350, height: UIView.layoutFittingCompressedSize.height))
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.layoutIfNeeded()

        guard let view = view else { return nil }
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size)
        return renderer.image { _ in view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yyyyMd")
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

#Preview {
    ShareCardView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
}
