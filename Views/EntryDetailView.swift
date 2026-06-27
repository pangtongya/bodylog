// EntryDetailView.swift
// Premium Apple HIG-style entry detail view

import SwiftUI

struct EntryDetailView: View {
    // MARK: - Dependencies

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - Inputs

    let entryID: UUID

    // MARK: - State

    @State private var showEditSheet: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showCompareSheet: Bool = false
    @State private var showPaywall: Bool = false

    // MARK: - Computed

    private var entry: BodyEntry? {
        entryStore.entries.first { $0.id == entryID }
    }

    private var hasPhoto: Bool {
        entry?.loadedPhotoData != nil
    }

    /// The entry recorded just before this one, for comparison.
    /// Returns nil if the entry store is empty, no entry is found, or the
    /// only candidate is recorded on the same calendar date.
    private var previousEntry: BodyEntry? {
        guard let current = entry, !entryStore.entries.isEmpty else { return nil }
        let candidates = entryStore.entries
            .filter { $0.id != current.id && $0.recordedAt < current.recordedAt }
        guard !candidates.isEmpty else { return nil }
        return candidates
            .sorted { $0.recordedAt > $1.recordedAt }
            .first
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLg) {
                if let entry = entry {
                    // 1. Metric Grid
                    metricsSection(entry: entry)

                    // 2. Photo Section
                    photoSection(entry: entry)

                    // 3. Note Card
                    if let note = entry.note, !note.isEmpty {
                        noteSection(text: note)
                    }

                    // 4. Comparison Section
                    if let previous = previousEntry,
                       !Calendar.current.isDate(previous.recordedAt, inSameDayAs: entry.recordedAt) {
                        comparisonSection(current: entry, previous: previous)
                    }
                }
            }
            .padding(.horizontal, .spacingLg)
            .padding(.vertical, .spacingMd)
        }
        .background(Color.formlogBgGrouped)
        .blNavigationBar()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Left: custom back button
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.formlogPrimary)
                        Text(L10n.string("返回"))
                            .font(.blBodyMedium)
                            .foregroundColor(.formlogPrimary)
                    }
                }
            }

            // Right: ellipsis menu
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        BodyLogHaptics.medium()
                        showEditSheet = true
                    }) {
                        Label(L10n.string("编辑"), systemImage: "pencil")
                    }
                    Button(role: .destructive, action: {
                        BodyLogHaptics.warning()
                        showDeleteAlert = true
                    }) {
                        Label(L10n.string("删除"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.formlogPrimary)
                }
                .accessibilityLabel(L10n.string("更多操作"))
            }
        }
        // Delete Alert
        .alert(L10n.string("删除记录"), isPresented: $showDeleteAlert) {
            Button(L10n.string("删除"), role: .destructive) {
                if let id = entry?.id {
                    entryStore.deleteEntry(id: id)
                    dismiss()
                }
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            if hasPhoto {
                Text(L10n.string("这条记录和照片将被永久删除，无法恢复。"))
            } else {
                Text(L10n.string("这条记录将被永久删除，无法恢复。"))
            }
        }
        // Edit Sheet
        .sheet(isPresented: $showEditSheet) {
            if let entry = entry {
                LogEntryView(isPresented: $showEditSheet, editingEntry: entry)
                    .environmentObject(appState)
                    .environmentObject(entryStore)
                    .environmentObject(goalStore)
            }
        }
        // Paywall Sheet
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(PurchaseManager.shared)
        }
        // Photo Compare Sheet
        .sheet(isPresented: $showCompareSheet) {
            PhotoCompareView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(purchaseManager)
        }
        // Context Menu (long press)
        .contextMenu {
            Button {
                BodyLogHaptics.medium()
                showEditSheet = true
            } label: {
                Label(L10n.string("编辑"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                BodyLogHaptics.warning()
                showDeleteAlert = true
            } label: {
                Label(L10n.string("删除"), systemImage: "trash")
            }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        guard let entry = entry else { return "" }
        return Self.navDateFormatter.string(from: entry.recordedAt)
    }

    // MARK: - Section: 2x2 Metric Grid

    private func metricsSection(entry: BodyEntry) -> some View {
        let metrics = BodyMetricType.allCases.filter { entry.metrics[$0.rawValue] != nil }
        let columns = [GridItem(.flexible(), spacing: .spacingMd), GridItem(.flexible(), spacing: .spacingMd)]
        return LazyVGrid(columns: columns, spacing: .spacingMd) {
            ForEach(metrics, id: \.self) { metric in
                if let val = entry.value(for: metric) {
                    metricCard(metric: metric, value: val)
                }
            }
        }
    }

    private func metricCard(metric: BodyMetricType, value: Double) -> some View {
        VStack(alignment: .leading, spacing: .spacingMd) {
            // Icon + label row
            HStack(spacing: .spacingSm) {
                blMetricIcon(metric.icon, color: metric.color, size: 30)
                Text(metric.displayName)
                    .font(.blFootnoteMedium)
                    .foregroundColor(.formlogTextSecondary)
                    .lineLimit(1)
            }

            // Large value + unit
            let display = formattedValue(value, type: metric)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(display.0)
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(.formlogTextPrimary)
                if !display.1.isEmpty {
                    Text(display.1)
                        .font(.blFootnote)
                        .foregroundColor(.formlogTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spacingLg)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 0.5)
        )
    }

    // MARK: - Section: Photo

    private func photoSection(entry: BodyEntry) -> some View {
        Group {
            if let data = entry.loadedPhotoData, let uiImage = UIImage(data: data) {
                photoCard(image: uiImage)
            } else {
                photoPlaceholderCard()
            }
        }
    }

    private func photoCard(image: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                .overlay(
                    RoundedRectangle(cornerRadius: .radiusXl)
                        .stroke(Color.formlogSeparator, lineWidth: 0.5)
                )

            // Compare button overlay at bottom
            compareButtonOverlay()
        }
    }

    private func photoPlaceholderCard() -> some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: .radiusXl)
                .fill(Color.formlogCard)
                .overlay(
                    RoundedRectangle(cornerRadius: .radiusXl)
                        .stroke(Color.formlogSeparator, lineWidth: 0.5)
                )

            VStack(spacing: .spacingSm) {
                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.formlogTextTertiary)
                Text(L10n.string("暂无照片"))
                    .font(.blFootnote)
                    .foregroundColor(.formlogTextTertiary)
            }
        }
        .frame(height: 160)
    }

    @ViewBuilder
    private func compareButtonOverlay() -> some View {
        if appState.isPro {
            Button {
                BodyLogHaptics.medium()
                showCompareSheet = true
            } label: {
                HStack(spacing: .spacingSm) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.string("对比照片"))
                        .font(.blSubheadSemibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, .spacingLg)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .accessibilityLabel(L10n.string("对比照片"))
            .padding(.bottom, .spacingMd)
        } else {
            Button {
                BodyLogHaptics.light()
                showPaywall = true
            } label: {
                HStack(spacing: .spacingXs) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.string("对比照片"))
                        .font(.blSubheadSemibold)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.formlogPrimary)
                        )
                }
                .foregroundColor(.formlogPrimary)
                .padding(.horizontal, .spacingLg)
                .padding(.vertical, 10)
                .background(Color.formlogPrimary.opacity(0.12), in: Capsule())
            }
            .accessibilityLabel(L10n.string("对比照片"))
            .padding(.bottom, .spacingMd)
        }
    }

    // MARK: - Section: Note

    private func noteSection(text: String) -> some View {
        HStack(alignment: .top, spacing: .spacingMd) {
            blMetricIcon("text.bubble.fill", color: .formlogPrimary, size: 30)
            Text(text)
                .font(.blBody)
                .foregroundColor(.formlogTextPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.spacingLg)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 0.5)
        )
    }

    // MARK: - Section: Comparison

    private func comparisonSection(current: BodyEntry, previous: BodyEntry) -> some View {
        let changes = computeChanges(current: current, previous: previous)
        if changes.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: .spacingMd) {
                // Section header
                HStack(spacing: .spacingXs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.formlogTextSecondary)
                    Text(L10n.string("与上次对比"))
                        .font(.blSubheadSemibold)
                        .foregroundColor(.formlogTextSecondary)
                    Spacer()
                    Text(Self.timeAgoFormatter.localizedString(for: previous.recordedAt, relativeTo: current.recordedAt))
                        .font(.blCaption1)
                        .foregroundColor(.formlogTextTertiary)
                }
                .padding(.horizontal, 4)

                // Change rows
                VStack(spacing: 0) {
                    ForEach(Array(changes.enumerated()), id: \.offset) { _, item in
                        comparisonRow(item: item)
                        if item != changes.last {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
                .padding(.horizontal, .spacingSm)
            }
            .padding(.spacingLg)
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        )
    }

    private struct ComparisonItem: Equatable {
        let metric: BodyMetricType
        let change: Double
        let formattedChange: String
        let isDecreasePositive: Bool  // true for weight/fat: decrease is good
    }

    private func comparisonRow(item: ComparisonItem) -> some View {
        HStack(spacing: .spacingMd) {
            // Metric icon
            blMetricIcon(item.metric.icon, color: item.metric.color, size: 30)

            // Metric name
            Text(item.metric.displayName)
                .font(.blBody)
                .foregroundColor(.formlogTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Change value
            let isPositive = item.isDecreasePositive ? item.change <= 0 : item.change >= 0
            let arrow = item.change > 0 ? "arrow.up.right" : item.change < 0 ? "arrow.down.right" : "minus"
            let tintColor: Color = item.change == 0
                ? .formlogTextTertiary
                : isPositive
                    ? .formlogDecrease
                    : .formlogDanger

            HStack(spacing: 4) {
                Image(systemName: arrow)
                    .font(.system(size: 11, weight: .bold))
                Text(item.formattedChange)
                    .font(.blFootnoteMedium.monospacedDigit())
            }
            .foregroundColor(tintColor)
        }
        .padding(.vertical, .spacingSm)
    }

    private func computeChanges(current: BodyEntry, previous: BodyEntry) -> [ComparisonItem] {
        var items: [ComparisonItem] = []
        let metrics = BodyMetricType.allCases.filter { current.metrics[$0.rawValue] != nil && previous.metrics[$0.rawValue] != nil }

        for metric in metrics {
            guard let curr = current.value(for: metric),
                  let prev = previous.value(for: metric) else { continue }

            let rawChange = curr - prev

            // Use display weight for weight/muscle
            let formatted: String
            if metric == .weight || metric == .muscleMass {
                let currDisplay = appState.displayWeight(curr)
                let prevDisplay = appState.displayWeight(prev)
                let displayChange = currDisplay.value - prevDisplay.value
                formatted = (displayChange > 0 ? "+" : "") + String(format: "%.1f %@", displayChange, currDisplay.unit)
            } else {
                formatted = (rawChange > 0 ? "+" : "") + String(format: "%.1f %@", rawChange, metric.unit)
            }

            // Decrease is positive for weight, body fat, waist, hip, neck, thigh, arm
            let decreasePositiveMetrics: Set<BodyMetricType> = [
                .weight, .bodyFat, .waist, .hip, .neck, .leftArm, .rightArm, .leftThigh, .rightThigh
            ]
            let isDecreasePositive = decreasePositiveMetrics.contains(metric)

            items.append(ComparisonItem(
                metric: metric,
                change: rawChange,
                formattedChange: formatted,
                isDecreasePositive: isDecreasePositive
            ))
        }
        return items
    }

    // MARK: - Formatting

    private static let navDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MdHHmm")
        return f
    }()

    private static let timeAgoFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale.current
        return f
    }()

    private func formattedValue(_ value: Double, type: BodyMetricType) -> (String, String) {
        if type == .weight || type == .muscleMass {
            let d = appState.displayWeight(value)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", value), type.unit)
    }
}
