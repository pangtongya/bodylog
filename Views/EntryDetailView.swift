// EntryDetailView.swift
// 单条记录详情页

import SwiftUI

struct EntryDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    let entry: BodyEntry

    @State private var showEditSheet: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showCompareSheet: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 指标网格
                metricsGrid
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
                        .sheet(isPresented: $showCompareSheet) {
                            PhotoCompareView()
                                .environmentObject(appState)
                                .environmentObject(entryStore)
                                .environmentObject(purchaseManager)
                        }
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
            .padding(.vertical, 16)
        }
        .background(Color.systemGroupedBackground)
        .navigationTitle(dateTitle)
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
            }
        }
        .alert(L10n.string("删除记录"), isPresented: $showDeleteAlert) {
            Button(L10n.string("删除"), role: .destructive) {
                entryStore.deleteEntry(id: entry.id)
                dismiss()
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            Text(L10n.string("这条记录将被永久删除，无法恢复。"))
        }
        .sheet(isPresented: $showEditSheet) {
            LogEntryView(isPresented: $showEditSheet, editingEntry: entry)
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(PurchaseManager.shared)
        }
    }

    private var metricsGrid: some View {
        let metrics = entry.metrics.keys.compactMap { BodyMetricType(rawValue: $0) }.sorted { $0.rawValue < $1.rawValue }
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

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: entry.recordedAt)
    }

    private func formattedValue(_ value: Double, type: BodyMetricType) -> (String, String) {
        if type == .weight || type == .muscleMass {
            let d = appState.displayWeight(value)
            return (String(format: "%.1f", d.value), d.unit)
        }
        return (String(format: "%.1f", value), type.unit)
    }
}
