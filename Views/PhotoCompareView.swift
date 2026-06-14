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
            .navigationTitle(showComparison ? "对比" : "照片对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showComparison {
                        Button("返回") {
                            withAnimation {
                                showComparison = false
                                selectedEntries.removeAll()
                            }
                        }
                        .foregroundColor(.bodylogPrimary)
                    } else {
                        Button("完成") {
                            dismiss()
                        }
                        .foregroundColor(.bodylogPrimary)
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
                                Text("对比 (\(selectedEntries.count)/2)")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(selectedEntries.count >= 2 ? .bodylogPrimary : .secondary)
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
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56))
                .foregroundColor(.bodylogPrimary.opacity(0.4))
            Text("还没有照片")
                .font(.system(size: 18, weight: .semibold))
            Text("在记录数据时拍摄形体照片\n之后可以在这里对比变化")
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
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                ForEach(entriesWithPhotos) { entry in
                    photoThumbnail(entry)
                }
            }
            .padding(2)
        }
        .background(Color.systemGroupedBackground)
    }
    
    private func photoThumbnail(_ entry: BodyEntry) -> some View {
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
                        .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                        .clipped()
                }
                
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.bodylogPrimary)
                            .frame(width: 24, height: 24)
                        Text("\(selectedEntries.firstIndex { $0.id == entry.id }! + 1)")
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
            VStack(spacing: 24) {
                // Photos side by side
                HStack(spacing: 12) {
                    if let entry1 = selectedEntries.first,
                       let data1 = entry1.loadedPhotoData,
                       let image1 = UIImage(data: data1) {
                        photoCard(image: image1, entry: entry1, tag: "之前") {
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
                        photoCard(image: image2, entry: entry2, tag: "之后") {
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
                
                // Time difference
                if let entry1 = selectedEntries.first, let entry2 = selectedEntries.last {
                    let days = Calendar.current.dateComponents([.day], from: entry1.recordedAt, to: entry2.recordedAt).day ?? 0
                    Text("相差 \(abs(days)) 天")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                // Metric changes
                if let entry1 = selectedEntries.first, let entry2 = selectedEntries.last {
                    metricChangesView(entry1: entry1, entry2: entry2)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.systemGroupedBackground)
    }
    
    private func photoCard(image: UIImage, entry: BodyEntry, tag: String, onRemove: (() -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            Text(tag)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.bodylogPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.bodylogPrimary.opacity(0.1))
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
            Text("指标变化")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
            
            let allMetrics = BodyMetricType.allCases.filter { type in
                entry1.value(for: type) != nil || entry2.value(for: type) != nil
            }
            
            ForEach(allMetrics, id: \.self) { type in
                let value1 = entry1.value(for: type) ?? 0
                let value2 = entry2.value(for: type) ?? 0
                let change = value2 - value1
                
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(.bodylogPrimary)
                        .frame(width: 24)
                    Text(type.displayName)
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(String(format: "%.1f", value1)) → \(String(format: "%.1f", value2))")
                        .font(.system(size: 14, design: .rounded).monospacedDigit())
                        .foregroundColor(.secondary)
                    Text(change >= 0 ? "+" : "")
                        + Text(String(format: "%.1f", change))
                            .foregroundColor(changeColor(change, type: type))
                }
                .padding(.vertical, 8)
                
                if type != allMetrics.last {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }
    
    private func changeColor(_ change: Double, type: BodyMetricType) -> Color {
        switch type {
        case .weight, .bodyFat, .waist, .hip:
            return change < 0 ? .bodylogDecrease : .bodylogDanger
        case .muscleMass:
            return change > 0 ? .bodylogDecrease : .bodylogDanger
        default:
            return .primary
        }
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

#Preview {
    PhotoCompareView()
        .environmentObject(BodyEntryStore())
}
