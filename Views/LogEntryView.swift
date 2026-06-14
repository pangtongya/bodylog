// LogEntryView.swift
// 记录数据 Sheet

import SwiftUI
import PhotosUI

struct LogEntryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @Binding var isPresented: Bool

    // Existing entry for editing
    var editingEntry: BodyEntry?

    @State private var metricValues: [BodyMetricType: String] = [:]
    @State private var note: String = ""
    @State private var recordDate: Date = Date()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showCamera: Bool = false
    @State private var showPhotoSourceDialog: Bool = false
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    private var isEditing: Bool { editingEntry != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date picker
                    datePicker

                    // Metric inputs
                    metricsSection

                    // Photo
                    photoSection

                    // Note
                    noteSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle(isEditing ? "编辑记录" : "记录数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "记录") {
                        saveEntry()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.bodylogPrimary)
                }
            }
        }
        .alert("输入有误", isPresented: $showValidationError) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .onAppear { prefillIfEditing() }
    }

    // MARK: - Sections

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("记录时间", systemImage: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            DatePicker("", selection: $recordDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("身体指标")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                let enabledMetrics = appState.enabledMetrics
                ForEach(Array(enabledMetrics.enumerated()), id: \.element) { idx, metric in
                    metricInputRow(metric: metric)
                    if idx < enabledMetrics.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color.systemBackground)
            .cornerRadius(12)
        }
    }

    private func metricInputRow(metric: BodyMetricType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.icon)
                .foregroundColor(.bodylogPrimary)
                .frame(width: 28)

            Text(metric.displayName)
                .font(.system(size: 15))

            Spacer()

            TextField("--", text: Binding(
                get: { metricValues[metric] ?? "" },
                set: { metricValues[metric] = $0 }
            ))
            .font(.system(size: 16, design: .rounded).monospacedDigit())
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)

            Text(metric == .weight || metric == .muscleMass ? appState.weightUnit.rawValue : metric.unit)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("形体照片（可选）", systemImage: "camera.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            if let data = photoData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)

                    Button(action: { photoData = nil; selectedPhotoItem = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("从相册选取")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(.bodylogPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.bodylogPrimary.opacity(0.1))
                    .cornerRadius(12)
                }
                .onChange(of: selectedPhotoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            // Compress to reduce storage
                            if let image = UIImage(data: data) {
                                photoData = image.jpegData(compressionQuality: 0.6)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("备注（可选）", systemImage: "text.bubble")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("今天感觉怎么样...", text: $note, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(3...6)
        }
        .padding(16)
        .background(Color.systemBackground)
        .cornerRadius(12)
    }

    // MARK: - Save

    private func saveEntry() {
        // Validate at least one metric filled
        let parsedMetrics: [String: Double] = metricValues.reduce(into: [:]) { result, pair in
            let metric = pair.key
            let str = pair.value.trimmingCharacters(in: .whitespaces)
            guard !str.isEmpty, let val = Double(str) else { return }
            // Convert weight unit
            let storeVal: Double
            if metric == .weight || metric == .muscleMass {
                storeVal = appState.toKg(val)
            } else {
                storeVal = val
            }
            // Validate range
            if metric.validRange.contains(storeVal) {
                result[metric.rawValue] = storeVal
            }
        }

        if parsedMetrics.isEmpty {
            validationMessage = "请至少填写一个指标"
            showValidationError = true
            return
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        if isEditing, var entry = editingEntry {
            entry.metrics = parsedMetrics
            entry.note = note.isEmpty ? nil : note
            entry.recordedAt = recordDate
            entry.photoData = photoData
            entryStore.updateEntry(entry)
        } else {
            let entry = BodyEntry(
                recordedAt: recordDate,
                metrics: parsedMetrics,
                note: note.isEmpty ? nil : note,
                photoData: photoData
            )
            entryStore.addEntry(entry)
            // Check goals
            goalStore.checkAndMarkAchieved(using: entryStore)
        }

        isPresented = false
    }

    private func prefillIfEditing() {
        guard let entry = editingEntry else { return }
        recordDate = entry.recordedAt
        note = entry.note ?? ""
        photoData = entry.photoData
        for metric in BodyMetricType.allCases {
            if let val = entry.value(for: metric) {
                if metric == .weight || metric == .muscleMass {
                    let display = appState.displayWeight(val)
                    metricValues[metric] = String(format: "%.1f", display.value)
                } else {
                    metricValues[metric] = String(format: "%.1f", val)
                }
            }
        }
    }
}

#Preview {
    LogEntryView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
