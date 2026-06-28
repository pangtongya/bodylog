// ShareCardView.swift
// Premium Apple-style share card — clean, white, print-ready aesthetic

import SwiftUI
import Photos
import os

struct ShareCardView: View {
    private let logger = Logger(subsystem: "com.pangtong.formlog", category: "ShareCardView")

    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var renderedImage: Image?
    @State private var shareItems: [Any] = []
    @State private var showShareSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing3Xl) {
                    // Card preview (the shareable card)
                    shareCardPreview
                        .padding(.horizontal, .spacingLg)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, .spacingLg)
                }
                .padding(.vertical, .spacingXl)
            }
            .background(Color.formlogBgGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) { dismiss() }
                        .font(.blBody)
                        .foregroundColor(.formlogTextSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.string("分享进度"))
                        .font(.blTitle3Semibold)
                        .foregroundColor(.formlogTextPrimary)
                }
            }
            .blNavigationBar()
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
            ?? "BodyLog"
    }

    // MARK: - Card Preview

    private var shareCardPreview: some View {
        cardContent
            // Force light mode: card always white background with dark text
            .environment(\.colorScheme, .light)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
    }

    // MARK: - Card Content (rendered as shareable image)

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header — brand + date + icon
            headerSection
                .padding(.bottom, .spacingLg)

            cardDivider

            // 3-column stats
            statsSection
                .padding(.vertical, .spacingXl)

            cardDivider

            // Latest metrics
            if let latest = entryStore.latestEntry, latest.hasAnyMetric {
                metricsSection(for: latest)
                    .padding(.vertical, .spacingLg)

                cardDivider
            }

            // Footer
            footerSection
                .padding(.top, .spacingLg)
        }
        .padding(.spacing2Xl)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: .spacingXs) {
                Text(appDisplayName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(cardForeground)
                Text(formatDate(Date()))
                    .font(.blCaption1)
                    .foregroundColor(cardSecondary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: "figure.stand")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.formlogPrimary)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            statColumn(
                value: "\(entryStore.totalRecordDays)",
                label: L10n.string("记录天数"),
                icon: "calendar"
            )

            statDivider

            statColumn(
                value: "\(entryStore.currentStreak)",
                label: L10n.string("连续天数"),
                icon: "flame.fill"
            )

            statDivider

            statColumn(
                value: "\(entryStore.entries.count)",
                label: L10n.string("总记录"),
                icon: "chart.bar.fill"
            )
        }
    }

    private func statColumn(value: String, label: String, icon: String) -> some View {
        VStack(spacing: .spacingSm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.formlogPrimary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(cardForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.blCaption1)
                .foregroundColor(cardSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(cardSecondary.opacity(0.2))
            .frame(width: 0.5)
            .padding(.vertical, .spacingSm)
    }

    // MARK: - Metrics Section

    private func metricsSection(for entry: BodyEntry) -> some View {
        VStack(alignment: .leading, spacing: .spacingMd) {
            Text(L10n.string("最近记录"))
                .font(.blSubheadSemibold)
                .foregroundColor(cardForeground)

            let displayMetrics = Array(entry.metrics.prefix(3))
            ForEach(displayMetrics, id: \.key) { key, value in
                if let type = BodyMetricType(rawValue: key) {
                    metricRow(type: type, value: value)
                }
            }
        }
    }

    private func metricRow(type: BodyMetricType, value: Double) -> some View {
        HStack(spacing: .spacingMd) {
            ZStack {
                RoundedRectangle(cornerRadius: .radiusSm)
                    .fill(type.color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(type.color)
            }

            Text(type.displayName)
                .font(.blSubhead)
                .foregroundColor(cardForeground)

            Spacer()

            Group {
                if type == .weight || type == .muscleMass {
                    let d = appState.displayWeight(value)
                    Text("\(String(format: "%.1f", d.value)) \(d.unit)")
                } else {
                    Text("\(String(format: "%.1f", value)) \(type.unit)")
                }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundColor(cardForeground)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text(L10n.string("隐私优先 · 数据本地存储"))
                .font(.blCaption2)
                .foregroundColor(cardSecondary)
            Spacer()
            Text(appDisplayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.formlogPrimary)
        }
    }

    // MARK: - Card Divider

    private var cardDivider: some View {
        Rectangle()
            .fill(cardSecondary.opacity(0.15))
            .frame(height: 0.5)
    }

    // MARK: - Card Colors (forced light)

    private var cardForeground: Color {
        Color(red: 0.110, green: 0.110, blue: 0.118)
    }

    private var cardSecondary: Color {
        Color(red: 0.560, green: 0.560, blue: 0.576)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: .spacingMd) {
            // Primary: Share
            Button(action: generateAndShare) {
                HStack(spacing: .spacingSm) {
                    Image(systemName: "square.and.arrow.up")
                    Text(L10n.string("分享这张卡片"))
                        .font(.blBodySemibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacingLg)
                .background(Color.formlogPrimary)
                .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
            }

            // Secondary: Save to Photos
            Button(action: saveToPhotos) {
                HStack(spacing: .spacingSm) {
                    Image(systemName: "photo.on.rectangle")
                    Text(L10n.string("保存到相册"))
                        .font(.blBody)
                }
                .foregroundColor(.formlogPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacingLg)
                .background(Color.formlogPrimary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
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
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            Task { @MainActor in
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    BodyLogHaptics.success()
                    logger.info("Photo saved successfully")
                } else {
                    logger.warning("Photo library access denied")
                    // TODO: Show error alert to user
                }
            }
        }
    }

    private func renderAsImage() -> UIImage? {
        let renderer = ImageRenderer(content: cardContent
            .frame(width: 350)
            .environment(\.colorScheme, .light)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    // MARK: - Date Formatting

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
