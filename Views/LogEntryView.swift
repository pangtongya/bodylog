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
    @State private var showPhotoPicker: Bool = false
    @State private var showPhotoSourceDialog: Bool = false
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""
    @State private var showCancelConfirmation: Bool = false
    /// 标记用户是否主动删除了照片（编辑模式下用于区分"没碰照片"和"主动删除"）
    @State private var photoWasRemoved: Bool = false
    @State private var prefillCompleted: Bool = false

    /// 检查用户是否已输入任何内容
    private var hasUserInput: Bool {
        let hasMetrics = metricValues.values.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let hasNote = !note.trimmingCharacters(in: .whitespaces).isEmpty
        let hasPhoto = photoData != nil
        return hasMetrics || hasNote || hasPhoto
    }

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
            .navigationTitle(isEditing ? L10n.string("编辑记录") : L10n.string("记录数据"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) {
                        if hasUserInput {
                            showCancelConfirmation = true
                        } else {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isPresented = false
                        }
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? L10n.string("保存") : L10n.string("记录")) {
                        saveEntry()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.formlogPrimary)
                }
            }
        }
        .alert(L10n.string("输入有误"), isPresented: $showValidationError) {
            Button(L10n.string("好的"), role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .confirmationDialog(L10n.string("放弃修改？"), isPresented: $showCancelConfirmation, titleVisibility: .visible) {
            Button(L10n.string("放弃修改"), role: .destructive) {
                isPresented = false
            }
            Button(L10n.string("继续编辑"), role: .cancel) {}
        }
        .onAppear { if !prefillCompleted { prefillIfEditing(); prefillCompleted = true } }
    }

    // MARK: - Sections

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.string("记录时间"), systemImage: "calendar")
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
            Text(L10n.string("身体指标"))
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
                .foregroundColor(.formlogPrimary)
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
            Label(L10n.string("形体照片（可选）"), systemImage: "camera.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            if let data = photoData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)

                    Button(action: {
                        photoData = nil
                        selectedPhotoItem = nil
                        photoWasRemoved = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                // Photo source menu
                Button(action: {
                    showPhotoSourceDialog = true
                }) {
                    HStack {
                        Image(systemName: "camera.badge.plus")
                        Text(L10n.string("添加照片"))
                            .font(.system(size: 15))
                    }
                    .foregroundColor(.formlogPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.formlogPrimary.opacity(0.1))
                    .cornerRadius(12)
                }
                .confirmationDialog(L10n.string("选择照片来源"), isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                    Button(L10n.string("拍照")) {
                        showCamera = true
                    }
                    Button(L10n.string("从相册选取")) {
                        showPhotoPicker = true
                    }
                    Button(L10n.string("取消"), role: .cancel) {}
                }
                .sheet(isPresented: $showCamera) {
                    CameraPicker(imageData: $photoData)
                }
                .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
                .onChange(of: selectedPhotoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
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
            Label(L10n.string("备注（可选）"), systemImage: "text.bubble")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            TextField(L10n.string("今天感觉怎么样..."), text: $note, axis: .vertical)
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
            validationMessage = L10n.string("请至少填写一个指标")
            showValidationError = true
            return
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        if isEditing, var entry = editingEntry {
            entry.metrics = parsedMetrics
            entry.note = note.isEmpty ? nil : note
            entry.recordedAt = recordDate
            // 保存旧照片文件名，替换或删除后清理，防止产生孤儿文件
            let oldPhotoFilename = entry.photoFilename
            if let data = photoData {
                if let filename = PhotoManager.shared.savePhoto(data) {
                    entry.photoFilename = filename
                    if let old = oldPhotoFilename, old != filename {
                        PhotoManager.shared.deletePhoto(filename: old)
                    }
                }
            } else if photoWasRemoved {
                entry.photoFilename = nil
                if let old = oldPhotoFilename {
                    PhotoManager.shared.deletePhoto(filename: old)
                }
            }
            entryStore.updateEntry(entry)
        } else {
            // 保存照片到文件
            let savedFilename: String? = photoData.flatMap { PhotoManager.shared.savePhoto($0) }

            let entry = BodyEntry(
                recordedAt: recordDate,
                metrics: parsedMetrics,
                note: note.isEmpty ? nil : note,
                photoFilename: savedFilename
            )
            entryStore.addEntry(entry)
        }

        // 检查成就解锁（新增和编辑都检查）
        checkAchievements()

        // Check goals
        goalStore.checkAndMarkAchieved(using: entryStore)

        isPresented = false
    }

    private func prefillIfEditing() {
        guard let entry = editingEntry else { return }
        recordDate = entry.recordedAt
        note = entry.note ?? ""
        photoData = entry.loadedPhotoData
        photoWasRemoved = false  // 重置删除标志
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

    /// 检查并解锁成就
    private func checkAchievements() {
        let newAchievements = AchievementManager.shared.checkAndUnlockAchievements(
            entryStore: entryStore,
            goalStore: goalStore,
            existingAchievements: appState.achievements
        )
        if !newAchievements.isEmpty {
            appState.unlockAchievements(newAchievements)
        }
    }
}

#Preview {
    LogEntryView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
