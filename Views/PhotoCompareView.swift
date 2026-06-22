// PhotoCompareView.swift
// 照片对比视图 - Pro功能

import SwiftUI

struct PhotoCompareView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedEntries: [BodyEntry] = []
    @State private var showComparison: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    
    private var entriesWithPhotos: [BodyEntry] {
        entryStore.entries.filter { $0.hasPhoto }
    }
    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showComparison {
                        Button(L10n.string("返回")) {
                            withAnimation {
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
                                    withAnimation {
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
                            .foregroundColor(selectedEntries.count >= 2 ? .formlogPrimary : .secondary)
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
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundColor(.formlogPrimary.opacity(0.4))
            Text(L10n.string("还没有照片"))
                .font(.system(size: 18, weight: .semibold))
            Text(L10n.string("在记录数据时拍摄形体照片\n之后可以在这里对比变化"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemGroupedBackground)
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    ForEach(entriesWithPhotos) { entry in
                        photoThumbnail(entry, itemSize: geo.size.width / 3 - 2)
                    }
                }
                .padding(2)
            }
            .background(Color.systemGroupedBackground)
        }
    }
    
    private func photoThumbnail(_ entry: BodyEntry, itemSize: CGFloat) -> some View {
        let isSelected = selectedEntries.contains { $0.id == entry.id }
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelected {
                selectedEntries.removeAll { $0.id == entry.id }
            } else {
                if selectedEntries.count < 2 {
                    selectedEntries.append(entry)
                    // 自动进入对比模式：当选中第2张照片且是Pro用户
                    if selectedEntries.count == 2 && appState.isPro {
                        withAnimation {
                            showComparison = true
                        }
                    } else if selectedEntries.count == 2 && !appState.isPro {
                        // 非Pro用户弹出付费墙
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
                
                // Date label
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(dateString(entry.recordedAt))
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
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
            VStack(spacing: 20) {
                // Title - more emotional
                Text(L10n.string("见证你的变化 💪"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Photos side by side - bigger and more prominent
                HStack(spacing: 12) {
                    if let entry1 = selectedEntries.first,
                       let data1 = entry1.loadedPhotoData,
                       let image1 = UIImage(data: data1) {
                        photoCard(image: image1, entry: entry1, tag: L10n.string("之前")) {
                            withAnimation {
                                selectedEntries.removeAll { $0.id == entry1.id }
                                if selectedEntries.count < 2 {
                                    showComparison = false
                                }
                            }
                        }
                    }
                    
                    if let entry2 = selectedEntries.last,
                       let data2 = entry2.loadedPhotoData,
                       let image2 = UIImage(data: data2) {
                        photoCard(image: image2, entry: entry2, tag: L10n.string("之后")) {
                            withAnimation {
                                selectedEntries.removeAll { $0.id == entry2.id }
                                if selectedEntries.count < 2 {
                                    showComparison = false
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Time difference - more prominent
                if let entry1 = selectedEntries.first, let entry2 = selectedEntries.last {
                    let days = Calendar.current.dateComponents([.day], from: entry1.recordedAt, to: entry2.recordedAt).day ?? 0
                    Text(String(format: L10n.string("📅 相差 %d 天"), abs(days)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                
                // Metric changes - improved layout with larger fonts
                if let entry1 = selectedEntries.first, let entry2 = selectedEntries.last {
                    metricChangesView(entry1: entry1, entry2: entry2)
                        .padding(.horizontal, 16)
                }
                
                // Share button
                Button(action: {
                    // Prepare share items: two photos
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
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L10n.string("分享对比"))
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.formlogPrimary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(Color.systemGroupedBackground)
    }
    
    private func photoCard(image: UIImage, entry: BodyEntry, tag: String, onRemove: (() -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            Text(tag)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.formlogPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.formlogPrimary.opacity(0.1))
                .cornerRadius(8)
            
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                
                if let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                    .buttonStyle(.plain)
                }
            }
            
            Text(dateString(entry.recordedAt))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    private func metricChangesView(entry1: BodyEntry, entry2: BodyEntry) -> some View {
        VStack(spacing: 0) {
            Text(L10n.string("📊 指标变化"))
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            
            let allMetrics = BodyMetricType.allCases.filter { type in
                entry1.value(for: type) != nil || entry2.value(for: type) != nil
            }

            ForEach(Array(allMetrics.enumerated()), id: \.element) { index, type in
                let value1 = entry1.value(for: type) ?? 0
                let value2 = entry2.value(for: type) ?? 0
                let change = value2 - value1
                
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: type.icon)
                        .foregroundColor(.formlogPrimary)
                        .frame(width: 28)
                        .font(.system(size: 16))
                    
                    // Metric name
                    Text(type.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Values
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.1f", value1))")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", value2))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    // Change
                    Text(change >= 0 ? "+" : "")
                    + Text(String(format: "%.1f", change))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(changeColor(change, type: type))
                }
                .padding(.vertical, 12)

                // Use index to determine if we need a divider
                if index < allMetrics.count - 1 {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(Color.systemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private func changeColor(_ change: Double, type: BodyMetricType) -> Color {
        switch type {
        case .weight, .bodyFat, .waist, .hip:
            return change < 0 ? .formlogDecrease : .formlogDanger
        case .muscleMass:
            return change > 0 ? .formlogDecrease : .formlogDanger
        default:
            return .primary
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yyyyMd")
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
