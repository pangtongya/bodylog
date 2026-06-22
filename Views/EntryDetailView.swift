// EntryDetailView.swift
// 单条记录详情页

import SwiftUI

struct EntryDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    let entryID: UUID

    @State private var showEditSheet: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showCompareSheet: Bool = false
    @State private var showPaywall: Bool = false

    private var entry: BodyEntry? {
        entryStore.entries.first { $0.id == entryID }
    }

    // 检查是否有照片
    private var hasPhoto: Bool {
        entry?.loadedPhotoData != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 指标网格
                if let entry = entry {
                    metricsGrid(entry: entry)
                        .padding(.horizontal, 20)

                    // 照片
                    if let data = entry.loadedPhotoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(16)
                            .padding(.horizontal, 20)

                        // 对比按钮
                        if appState.isPro {
                            Button(action: {
                                showCompareSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.stack.fill")
                                    Text(L10n.string("对比照片"))
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.formlogPrimary)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        } else {
                            // Non-Pro: show locked hint
                            Button(action: { showPaywall = true }) {
                                HStack {
                                    Image(systemName: "photo.stack.fill")
                                    Text(L10n.string("对比照片"))
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.formlogPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.formlogPrimary.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // 备注
                    if let note = entry.note, !note.isEmpty {
                        noteCard(note)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.systemGroupedBackground)
        .navigationTitle(entry.map { Self.dateFormatter.string(from: $0.recordedAt) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showEditSheet = true }) {
                        Label(L10n.string("编辑"), systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label(L10n.string("删除"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.formlogPrimary)
                }
                .accessibilityLabel(L10n.string("更多操作"))
            }
        }
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
        .sheet(isPresented: $showEditSheet) {
            if let entry = entry {
                LogEntryView(isPresented: $showEditSheet, editingEntry: entry)
                    .environmentObject(appState)
                    .environmentObject(entryStore)
                    .environmentObject(goalStore)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(PurchaseManager.shared)
        }
        .sheet(isPresented: $showCompareSheet) {
            PhotoCompareView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(purchaseManager)
        }
    }

    private func metricsGrid(entry: BodyEntry) -> some View {
        let metrics = BodyMetricType.allCases.filter { entry.metrics[$0.rawValue] != nil }
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(metrics, id: \.self) { metric in
                if let val = entry.value(for: metric) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: metric.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.formlogPrimary)
                            Text(metric.displayName)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        let display = formattedValue(val, type: metric)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(display.0)
                                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                            Text(display.1)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.systemBackground)
                    .cornerRadius(12)
                }
            }
        }
    }

    private func noteCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.bubble.fill")
                .foregroundColor(.formlogPrimary.opacity(0.7))
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MdHHmm")
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
