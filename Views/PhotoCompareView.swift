// PhotoCompareView.swift
// Premium Apple HIG Photo Comparison View

import SwiftUI
import Photos
import os.log

private let photoCompareLogger = Logger(subsystem: "com.pangtong.formlog", category: "PhotoCompareView")

struct PhotoCompareView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedEntries: [BodyEntry] = []
    @State private var showComparison: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    @State private var isSliderMode: Bool = false
    @State private var sliderPosition: CGFloat = 0.5
    @State private var showSaveSuccess: Bool = false

    // MARK: - Computed

    private var entriesWithPhotos: [BodyEntry] {
        entryStore.entries.filter { $0.hasPhoto }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if entriesWithPhotos.isEmpty {
                    emptyState
                } else if showComparison, selectedEntries.count == 2 {
                    comparisonView
                } else {
                    photoGrid
                }
            }
            .navigationTitle(showComparison ? L10n.string("对比") : L10n.string("照片对比"))
            .navigationBarTitleDisplayMode(.inline)
            .blNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showComparison {
                        Button(L10n.string("返回")) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showComparison = false
                                selectedEntries.removeAll()
                            }
                        }
                        .foregroundColor(.formlogPrimary)
                    } else {
                        Button(L10n.string("完成")) {
                            dismiss()
                        }
                        .foregroundColor(.formlogPrimary)
                    }
                }

                if !showComparison && !selectedEntries.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            if selectedEntries.count >= 2 {
                                if appState.isPro {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showComparison = true
                                    }
                                } else {
                                    showPaywall = true
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                if !appState.isPro {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                }
                                Text(String(format: L10n.string("对比 (%d/2)"), selectedEntries.count))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(selectedEntries.count >= 2 ? .formlogPrimary : .formlogTextSecondary)
                        }
                        .disabled(selectedEntries.count < 2)
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: .spacingLg) {
            ZStack {
                Circle()
                    .fill(Color.formlogPrimary.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "photo.stack")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.formlogPrimary)
            }
            Text(L10n.string("还没有照片"))
                .font(.blTitle3Semibold)
                .foregroundColor(.formlogTextPrimary)
            Text(L10n.string("在记录数据时拍摄形体照片\n之后可以在这里对比变化"))
                .font(.blSubhead)
                .foregroundColor(.formlogTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.formlogBgGrouped)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 2
                ) {
                    ForEach(entriesWithPhotos) { entry in
                        photoThumbnail(entry, itemSize: geo.size.width / 3 - 2)
                    }
                }
                .padding(2)
            }
            .background(Color.formlogBgGrouped)
        }
    }

    private func photoThumbnail(_ entry: BodyEntry, itemSize: CGFloat) -> some View {
        let isSelected = selectedEntries.contains { $0.id == entry.id }

        return Button(action: {
            BodyLogHaptics.light()
            if isSelected {
                selectedEntries.removeAll { $0.id == entry.id }
            } else {
                if selectedEntries.count < 2 {
                    selectedEntries.append(entry)
                    if selectedEntries.count == 2 && appState.isPro {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showComparison = true
                        }
                    } else if selectedEntries.count == 2 && !appState.isPro {
                        showPaywall = true
                    }
                }
            }
        }) {
            ZStack(alignment: .topTrailing) {
                if let data = entry.loadedPhotoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: itemSize, height: itemSize)
                        .clipped()
                } else {
                    ZStack {
                        Color.formlogFillTertiary
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(.formlogTextQuaternary)
                    }
                    .frame(width: itemSize, height: itemSize)
                }

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.formlogPrimary)
                            .frame(width: 24, height: 24)
                        Text("\((selectedEntries.firstIndex { $0.id == entry.id } ?? 0) + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(6)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(dateString(entry.recordedAt))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comparison View

    private var comparisonView: some View {
        ScrollView {
            VStack(spacing: .spacingLg) {
                // Mode toggle
                modeToggle
                    .padding(.horizontal, .spacingLg)

                // Photo comparison area
                if isSliderMode {
                    beforeAfterSlider
                        .padding(.horizontal, .spacingLg)
                } else {
                    sideBySidePhotos
                        .padding(.horizontal, .spacingLg)
                }

                // Time difference badge
                timeDifferenceBadge
                    .padding(.horizontal, .spacingLg)

                // Metric changes card
                if let entry1 = selectedEntries.first, let entry2 = selectedEntries.last {
                    metricChangesCard(entry1: entry1, entry2: entry2)
                        .padding(.horizontal, .spacingLg)
                }

                // Action buttons
                actionButtons
                    .padding(.horizontal, .spacingLg)
                    .padding(.bottom, .spacing3Xl)
            }
            .padding(.top, .spacingSm)
        }
        .background(Color.formlogBgGrouped)
        .overlay {
            if showSaveSuccess {
                VStack {
                    Spacer()
                    HStack(spacing: .spacingSm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text(L10n.string("已保存到相册"))
                            .font(.blBodyMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, .spacingXl)
                    .padding(.vertical, .spacingMd)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: .radiusLg))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .padding(.bottom, .spacing4Xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSaveSuccess = false }
                    }
                }
            }
        }
    }

    // MARK: - Mode Toggle (Segmented)

    private var modeToggle: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isSliderMode = false } }) {
                Text(L10n.string("并排"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(!isSliderMode ? .formlogPrimary : .formlogTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacingSm)
                    .background(
                        RoundedRectangle(cornerRadius: .radiusMd)
                            .fill(!isSliderMode ? Color.formlogFillTertiary : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isSliderMode = true } }) {
                Text(L10n.string("滑动"))
                    .font(.blSubheadSemibold)
                    .foregroundColor(isSliderMode ? .formlogPrimary : .formlogTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spacingSm)
                    .background(
                        RoundedRectangle(cornerRadius: .radiusMd)
                            .fill(isSliderMode ? Color.formlogFillTertiary : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(Color.formlogFillSecondary, in: RoundedRectangle(cornerRadius: .radiusMd))
    }

    // MARK: - Side-by-Side Photos

    private var sideBySidePhotos: some View {
        HStack(alignment: .top, spacing: .spacingSm) {
            if let entry1 = selectedEntries.first {
                let image1 = entry1.loadedPhotoData.flatMap { UIImage(data: $0) }
                if let image1 {
                    comparisonPhotoCard(image: image1, entry: entry1, label: L10n.string("之前"))
                } else {
                    comparisonPlaceholderCard(entry: entry1, label: L10n.string("之前"))
                }
            }

            if let entry2 = selectedEntries.last {
                let image2 = entry2.loadedPhotoData.flatMap { UIImage(data: $0) }
                if let image2 {
                    comparisonPhotoCard(image: image2, entry: entry2, label: L10n.string("之后"))
                } else {
                    comparisonPlaceholderCard(entry: entry2, label: L10n.string("之后"))
                }
            }
        }
    }

    private func comparisonPhotoCard(image: UIImage, entry: BodyEntry, label: String) -> some View {
        VStack(spacing: 0) {
            // Label + date row
            VStack(spacing: 6) {
                Text(label)
                    .font(.blCaption1)
                    .fontWeight(.semibold)
                    .foregroundColor(.formlogPrimary)
                    .tracking(0.5)

                Text(dateString(entry.recordedAt))
                    .font(.blFootnote)
                    .foregroundColor(.formlogTextSecondary)
            }
            .padding(.vertical, .spacingSm)

            // Photo
            ZStack {
                Color.formlogFillTertiary
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity)
        .background(Color.formlogCard, in: RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 0.5)
        )
    }

    private func comparisonPlaceholderCard(entry: BodyEntry, label: String) -> some View {
        VStack(spacing: 0) {
            // Label + date row
            VStack(spacing: 6) {
                Text(label)
                    .font(.blCaption1)
                    .fontWeight(.semibold)
                    .foregroundColor(.formlogPrimary)
                    .tracking(0.5)

                Text(dateString(entry.recordedAt))
                    .font(.blFootnote)
                    .foregroundColor(.formlogTextSecondary)
            }
            .padding(.vertical, .spacingSm)

            // Placeholder
            ZStack {
                Color.formlogFillTertiary
                VStack(spacing: .spacingSm) {
                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.formlogTextQuaternary)
                    Text(L10n.string("暂无照片"))
                        .font(.blSubhead)
                        .foregroundColor(.formlogTextQuaternary)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity)
        .background(Color.formlogCard, in: RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 0.5)
        )
    }

    // MARK: - Before / After Slider

    private var beforeAfterSlider: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                if let entry1 = selectedEntries.first {
                    let image1 = entry1.loadedPhotoData.flatMap { UIImage(data: $0) }
                    let image2 = selectedEntries.last?.loadedPhotoData.flatMap { UIImage(data: $0) }

                    if let image1 {
                        // Before (full, bottom layer)
                        Image(uiImage: image1)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()

                        // After (masked by slider)
                        if let image2 {
                            Image(uiImage: image2)
                                .resizable()
                                .scaledToFill()
                                .frame(width: width, height: height)
                                .clipped()
                                .mask(
                                    Rectangle()
                                        .frame(width: width * sliderPosition)
                                )
                        } else {
                            // Placeholder for after image
                            Color.formlogFillTertiary
                                .frame(width: width, height: height)
                                .overlay(
                                    Text(L10n.string("暂无照片"))
                                        .font(.blSubhead)
                                        .foregroundColor(.formlogTextQuaternary)
                                )
                                .mask(
                                    Rectangle()
                                        .frame(width: width * sliderPosition)
                                )
                        }

                        // Slider line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .position(x: width * sliderPosition, y: height / 2)

                        // Slider handle
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.25), radius: 6)
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.formlogTextPrimary)
                        }
                        .position(x: width * sliderPosition, y: height / 2)

                        // Labels
                        VStack {
                            HStack {
                                Text(L10n.string("之前"))
                                    .font(.blCaption1)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.spacingMd)
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Spacer()
                                Text(L10n.string("之后"))
                                    .font(.blCaption1)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(.spacingMd)
                            }
                        }
                    } else {
                        // Both photos unavailable — show a full placeholder
                        Color.formlogFillTertiary
                            .overlay(
                                VStack(spacing: .spacingSm) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.formlogTextQuaternary)
                                    Text(L10n.string("暂无照片"))
                                        .font(.blSubhead)
                                        .foregroundColor(.formlogTextQuaternary)
                                }
                            )
                    }
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPosition = value.location.x / width
                        sliderPosition = min(max(newPosition, 0.05), 0.95)
                    }
            )
        }
        .frame(height: 340)
    }

    // MARK: - Time Difference Badge

    private var timeDifferenceBadge: some View {
        Group {
            if let entry1 = selectedEntries.first, let entry2 = selectedEntries.last {
                let days = Calendar.current.dateComponents([.day], from: entry1.recordedAt, to: entry2.recordedAt).day ?? 0
                HStack(spacing: .spacingSm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .medium))
                    Text(String(format: L10n.string("相差 %d 天"), abs(days)))
                        .font(.blSubheadSemibold)
                }
                .foregroundColor(.formlogTextSecondary)
                .padding(.horizontal, .spacingLg)
                .padding(.vertical, .spacingSm)
                .background(Color.formlogFillTertiary, in: Capsule())
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Metric Changes Card

    private func metricChangesCard(entry1: BodyEntry, entry2: BodyEntry) -> some View {
        let allMetrics = BodyMetricType.allCases.filter { type in
            entry1.value(for: type) != nil || entry2.value(for: type) != nil
        }

        return VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: .spacingSm) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
                Text(L10n.string("指标变化"))
                    .font(.blTitle3Semibold)
                    .foregroundColor(.formlogTextPrimary)
                Spacer()
            }
            .padding(.horizontal, .spacingXl)
            .padding(.top, .spacingLg)
            .padding(.bottom, .spacingMd)

            // Table header
            HStack(spacing: .spacingMd) {
                Spacer()
                Text(L10n.string("之前"))
                    .font(.blCaption1)
                    .foregroundColor(.formlogTextTertiary)
                    .frame(width: 50, alignment: .trailing)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.formlogTextQuaternary)

                Text(L10n.string("之后"))
                    .font(.blCaption1)
                    .foregroundColor(.formlogTextTertiary)
                    .frame(width: 50, alignment: .trailing)

                Text(L10n.string("变化"))
                    .font(.blCaption1)
                    .foregroundColor(.formlogTextTertiary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, .spacingXl)
            .padding(.bottom, .spacingSm)

            // Separator
            Color.formlogSeparator
                .frame(height: 0.5)
                .padding(.horizontal, .spacingXl)

            // Metric rows
            ForEach(Array(allMetrics.enumerated()), id: \.element) { index, type in
                metricRow(type: type, entry1: entry1, entry2: entry2)
                    .padding(.horizontal, .spacingXl)

                if index < allMetrics.count - 1 {
                    Color.formlogSeparator
                        .frame(height: 0.5)
                        .padding(.horizontal, .spacingXl)
                }
            }

            if !allMetrics.isEmpty {
                Color.formlogSeparator
                    .frame(height: 0.5)
                    .padding(.horizontal, .spacingXl)
                    .padding(.bottom, .spacingSm)
            }
        }
        .background(Color.formlogCard, in: RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 0.5)
        )
    }

    private func metricRow(type: BodyMetricType, entry1: BodyEntry, entry2: BodyEntry) -> some View {
        let value1 = entry1.value(for: type) ?? 0
        let value2 = entry2.value(for: type) ?? 0
        let change = value2 - value1
        let hasValue1 = entry1.value(for: type) != nil
        let hasValue2 = entry2.value(for: type) != nil

        return HStack(spacing: .spacingMd) {
            // Icon + name
            HStack(spacing: .spacingSm) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(type.color)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(type.color.opacity(0.12))
                    )

                Text(type.displayName)
                    .font(.blBody)
                    .foregroundColor(.formlogTextPrimary)
                    .lineLimit(1)
            }

            Spacer()

            // Before value
            Text(hasValue1 ? String(format: "%.1f", value1) : "-")
                .font(.blMonoFootnote)
                .foregroundColor(hasValue1 ? .formlogTextSecondary : .formlogTextQuaternary)
                .frame(width: 50, alignment: .trailing)

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.formlogTextQuaternary)

            // After value
            Text(hasValue2 ? String(format: "%.1f", value2) : "-")
                .font(.blMonoFootnote)
                .foregroundColor(hasValue2 ? .formlogTextPrimary : .formlogTextQuaternary)
                .frame(width: 50, alignment: .trailing)

            // Change amount
            if hasValue1 && hasValue2 {
                let formatted = change >= 0 ? "+\(String(format: "%.1f", change))" : String(format: "%.1f", change)
                Text(formatted)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(changeColor(change, type: type))
                    .frame(width: 60, alignment: .trailing)
            } else {
                Text("-")
                    .font(.blMonoFootnote)
                    .foregroundColor(.formlogTextQuaternary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, .spacingMd)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: .spacingSm) {
            // Share button (primary)
            Button(action: shareComparison) {
                HStack(spacing: .spacingSm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L10n.string("分享对比"))
                        .font(.blBodySemibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.formlogPrimary, in: RoundedRectangle(cornerRadius: .radiusXl))
            }

            // Save comparison button (secondary)
            Button(action: saveComparisonImage) {
                HStack(spacing: .spacingSm) {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L10n.string("保存对比图"))
                        .font(.blBodySemibold)
                }
                .foregroundColor(.formlogPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.formlogPrimarySoft, in: RoundedRectangle(cornerRadius: .radiusXl))
                .overlay(
                    RoundedRectangle(cornerRadius: .radiusXl)
                        .stroke(Color.formlogPrimary.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Share Logic

    private func shareComparison() {
        var items: [Any] = []
        if let entry1 = selectedEntries.first,
           let data1 = entry1.loadedPhotoData,
           let image1 = UIImage(data: data1) {
            items.append(image1)
        }
        if let entry2 = selectedEntries.last,
           let data2 = entry2.loadedPhotoData,
           let image2 = UIImage(data: data2) {
            items.append(image2)
        }
        shareItems = items
        showShareSheet = true
    }

    // MARK: - Color Logic

    private func changeColor(_ change: Double, type: BodyMetricType) -> Color {
        if change == 0 { return .formlogTextSecondary }
        switch type {
        case .weight, .bodyFat, .waist, .hip:
            return change < 0 ? .formlogDecrease : .formlogDanger
        case .muscleMass:
            return change > 0 ? .formlogDecrease : .formlogDanger
        default:
            return .formlogTextPrimary
        }
    }

    // MARK: - Save Comparison Image

    private func saveComparisonImage() {
        guard let entry1 = selectedEntries.first,
              let data1 = entry1.loadedPhotoData,
              let image1 = UIImage(data: data1),
              let entry2 = selectedEntries.last,
              let data2 = entry2.loadedPhotoData,
              let image2 = UIImage(data: data2) else { return }

        let comparisonImage = generateComparisonImage(
            before: image1, after: image2,
            date1: entry1.recordedAt, date2: entry2.recordedAt
        )

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: comparisonImage)
        }) { success, error in
            Task { @MainActor in
                if success {
                    showSaveSuccess = true
                    BodyLogHaptics.medium()
                } else {
                    photoCompareLogger.error("Failed to save comparison image: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
    }

    private func generateComparisonImage(before: UIImage, after: UIImage, date1: Date, date2: Date) -> UIImage {
        let size = CGSize(width: 1200, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // Background
            UIColor.black.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            let halfWidth = size.width / 2
            let imageHeight = size.height - 100

            // Draw before image (left)
            let beforeRect = CGRect(x: 0, y: 0, width: halfWidth, height: imageHeight)
            before.draw(in: beforeRect, blendMode: .normal, alpha: 1.0)

            // Draw after image (right)
            let afterRect = CGRect(x: halfWidth, y: 0, width: halfWidth, height: imageHeight)
            after.draw(in: afterRect, blendMode: .normal, alpha: 1.0)

            // Divider line
            UIColor.white.setStroke()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: halfWidth, y: 0))
            linePath.addLine(to: CGPoint(x: halfWidth, y: imageHeight))
            linePath.lineWidth = 2
            linePath.stroke()

            // Labels
            let formatter = Self.comparisonDateFormatter

            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            let beforeLabel = "\(L10n.string("之前"))  \(formatter.string(from: date1))"
            beforeLabel.draw(at: CGPoint(x: 20, y: imageHeight + 30), withAttributes: labelAttrs)

            let afterLabel = "\(L10n.string("之后"))  \(formatter.string(from: date2))"
            let afterSize = afterLabel.size(withAttributes: labelAttrs)
            afterLabel.draw(at: CGPoint(x: size.width - afterSize.width - 20, y: imageHeight + 30), withAttributes: labelAttrs)

            // App branding
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0)
            ]
            let brandText = "FormLog"
            let brandSize = brandText.size(withAttributes: brandAttrs)
            brandText.draw(at: CGPoint(x: (size.width - brandSize.width) / 2, y: imageHeight + 35), withAttributes: brandAttrs)
        }
    }

    // MARK: - Date Formatting

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yyyyMd")
        return f
    }()

    private static let comparisonDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    private func dateString(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

#Preview {
    PhotoCompareView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(PurchaseManager.shared)
}
