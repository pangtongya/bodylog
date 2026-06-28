// LogEntryView.swift
// Premium Data Entry Sheet — Apple HIG iOS Settings Style

import SwiftUI
import PhotosUI

struct LogEntryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @Binding var isPresented: Bool

    var editingEntry: BodyEntry?

    @State private var metricValues: [BodyMetricType: String] = [:]
    @State private var note: String = ""
    @State private var recordDate: Date = Date()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showCamera: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var showPhotoSourceDialog: Bool = false
    @State private var metricValuesChanged: [BodyMetricType: Bool] = [:]
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""
    @State private var showCancelConfirmation: Bool = false
    @State private var showPhotoSizeWarning: Bool = false
    @State private var photoWasRemoved: Bool = false
    @State private var prefillCompleted: Bool = false
    @State private var isSaving: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showCelebration: Bool = false
    @State private var isFirstRecord: Bool = false

    @FocusState private var focusedField: FocusableField?

    private enum FocusableField: Hashable {
        case metric(BodyMetricType)
        case note
    }

    private let maxPhotoSize: Int64 = 5 * 1024 * 1024

    private var hasUserInput: Bool {
        let hasMetrics = metricValues.values.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let hasNote = !note.trimmingCharacters(in: .whitespaces).isEmpty
        let hasPhoto = photoData != nil
        return hasMetrics || hasNote || hasPhoto
    }

    private var isEditing: Bool { editingEntry != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 28) {
                        // Date row card
                        datePickerSection

                        // Body metrics — hero section
                        metricsSection

                        // Photo section
                        photoSection

                        // Note section
                        noteSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
                .background(Color.formlogBgGrouped)
                .scrollDismissesKeyboard(.interactively)

                // First entry celebration overlay
                if showCelebration {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.formlogPrimary)
                            Text(L10n.string("第一次记录成功！"))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(L10n.string("坚持 7 天解锁成就徽章 🏅"))
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(32)
                        .background(Color.formlogCard)
                        .cornerRadius(20)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showCelebration)
                }

                // Loading overlay during save
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)
                                .progressViewStyle(CircularProgressViewStyle(tint: .formlogPrimary))
                            Text(L10n.string("保存中..."))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.formlogTextPrimary)
                        }
                        .padding(24)
                        .background(Color.formlogCard)
                        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                    }
                }

                // Fixed bottom save button
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.formlogBgGrouped.opacity(0), Color.formlogBgGrouped],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)

                    Button(action: saveEntry) {
                        let title = isEditing ? L10n.string("保存修改") : L10n.string("记录今天数据")
                        return Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.formlogPrimary)
                            .cornerRadius(.radiusXl)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .background(Color.formlogBgGrouped)
                    .accessibilityLabel(isEditing ? L10n.string("保存修改") : L10n.string("记录今天数据"))
                    .accessibilityHint(L10n.string("双击保存"))
                    .accessibilityAddTraits(.isButton)
                }
            }
            .background(Color.formlogBgGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) {
                        if hasUserInput {
                            showCancelConfirmation = true
                        } else {
                            BodyLogHaptics.light()
                            isPresented = false
                        }
                    }
                    .foregroundColor(Color.formlogTextSecondary)
                    .accessibilityLabel(L10n.string("取消"))
                    .accessibilityHint(L10n.string("返回上一页"))
                }
                ToolbarItem(placement: .principal) {
                    Text(L10n.string("记录数据"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.formlogTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? L10n.string("保存") : L10n.string("记录")) {
                        saveEntry()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.formlogPrimary)
                    .accessibilityLabel(isEditing ? L10n.string("保存修改") : L10n.string("记录数据"))
                    .accessibilityHint(L10n.string("双击保存"))
                }
            }
            .blNavigationBar()
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: $photoData)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
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
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    if data.count > maxPhotoSize {
                        let sizeMB = Double(data.count) / (1024.0 * 1024.0)
                        validationMessage = String(format: L10n.string("照片过大（%.1fMB），最大支持 5MB"), sizeMB)
                        showValidationError = true
                        return
                    }

                    if let image = UIImage(data: data) {
                        photoData = compressImage(image, targetSizeKB: 800)
                    }
                }
            }
        }
        .onAppear {
            if !prefillCompleted {
                prefillIfEditing()
                prefillCompleted = true
            }
        }
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    L10n.string("记录时间"),
                    selection: $recordDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                Button {
                    showDatePicker = false
                    BodyLogHaptics.light()
                } label: {
                    Text(L10n.string("完成"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.formlogPrimary)
                        .cornerRadius(.radiusXl)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color.formlogBgGrouped)
            .navigationTitle(L10n.string("选择日期"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.string("取消")) {
                        showDatePicker = false
                    }
                    .foregroundColor(Color.formlogTextSecondary)
                }
            }
            .blNavigationBar()
        }
    }

    // MARK: - Date Picker Section (Card Row)

    private var datePickerSection: some View {
        Button {
            showDatePicker = true
            BodyLogHaptics.light()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.formlogBlue)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.formlogBlue.opacity(0.12))
                    )

                Text(L10n.string("记录时间"))
                    .font(.system(size: 17))
                    .foregroundColor(Color.formlogTextPrimary)

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 15))
                    .foregroundColor(Color.formlogTextSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.formlogTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record time \(formattedDate)")
        .accessibilityHint("双击修改记录时间")
    }

    private static let dateInputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var formattedDate: String {
        Self.dateInputFormatter.string(from: recordDate)
    }

    // MARK: - Metrics Section (iOS Inset Grouped Card)

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("身体指标"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.formlogTextSecondary)
                .textCase(.uppercase)
                .tracking(0.2)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                let enabledMetrics = appState.enabledMetrics
                ForEach(Array(enabledMetrics.enumerated()), id: \.element) { idx, metric in
                    metricInputRow(metric: metric)
                    if idx < enabledMetrics.count - 1 {
                        separator(insetLeft: 52)
                    }
                }
            }
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
    }

    private func separator(insetLeft: CGFloat) -> some View {
        Rectangle()
            .fill(Color.formlogSeparator)
            .frame(height: 0.5)
            .padding(.leading, insetLeft)
            .padding(.trailing, 16)
    }

    private func metricInputRow(metric: BodyMetricType) -> some View {
        HStack(spacing: 12) {
            // Colored circle icon — 28px with metric-specific color at 0.12 bg
            Circle()
                .fill(metricAccentColor(for: metric).opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: metric.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(metricAccentColor(for: metric))
                )

            Text(metric.displayName)
                .font(.system(size: 17))
                .foregroundColor(Color.formlogTextPrimary)

            Spacer()

            // Right-aligned numeric input
            HStack(spacing: 4) {
                TextField("--", text: Binding(
                    get: { metricValues[metric] ?? "" },
                    set: {
                        metricValues[metric] = $0
                        metricValuesChanged[metric] = true
                    }
                ))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80, alignment: .trailing)
                .focused($focusedField, equals: .metric(metric))

                Text(displayUnit(for: metric))
                    .font(.system(size: 15))
                    .foregroundColor(Color.formlogTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityLabel("\(metric.displayName) \(displayUnit(for: metric)) input")
        .accessibilityHint("Enter \(metric.displayName) value")
    }

    /// Uses the new formlogWeight/formlogBodyFat/formlogMuscle/formlogBMI color tokens
    private func metricAccentColor(for type: BodyMetricType) -> Color {
        switch type {
        case .weight:
            return .formlogWeight
        case .bodyFat:
            return .formlogBodyFat
        case .muscleMass:
            return .formlogMuscle
        case .bmi:
            return .formlogBMI
        case .waist:
            return .formlogWaist
        case .chest:
            return .formlogChest
        default:
            return .formlogPurple
        }
    }

    private func displayUnit(for metric: BodyMetricType) -> String {
        if metric == .weight || metric == .muscleMass {
            return appState.weightUnit.rawValue
        }
        return metric.unit
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.formlogTextSecondary)
                Text(L10n.string("形体照片（可选）"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.formlogTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.2)
            }
            .padding(.horizontal, 4)

            Group {
                if let data = photoData, let uiImage = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: .radiusMd))

                        Button(action: {
                            photoData = nil
                            selectedPhotoItem = nil
                            photoWasRemoved = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
                    .padding(12)
                } else {
                    Button(action: {
                        showPhotoSourceDialog = true
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.formlogPrimary.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.formlogPrimary)
                            }
                            Text(L10n.string("添加照片"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.formlogPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: .radiusMd)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                .foregroundColor(Color.formlogSeparatorOpaque)
                        )
                        .padding(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("添加照片"))
                    .accessibilityHint(L10n.string("双击拍照或从相册选取照片"))
                    .confirmationDialog(L10n.string("选择照片来源"), isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                        Button(L10n.string("拍照")) {
                            showCamera = true
                        }
                        Button(L10n.string("从相册选取")) {
                            showPhotoPicker = true
                        }
                        Button(L10n.string("取消"), role: .cancel) {}
                    }
                }
            }
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color.formlogTextSecondary)
                Text(L10n.string("备注（可选）"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.formlogTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.2)
            }
            .padding(.horizontal, 4)

            TextField(L10n.string("今天感觉怎么样..."), text: $note, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(Color.formlogTextPrimary)
                .lineLimit(3...6)
                .focused($focusedField, equals: .note)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.formlogCard)
                .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
                .overlay(
                    RoundedRectangle(cornerRadius: .radiusXl)
                        .stroke(Color.formlogSeparator, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Save

    private func saveEntry() {
        let parsedMetrics: [String: Double] = metricValues.reduce(into: [:]) { result, pair in
            let metric = pair.key
            let str = pair.value.trimmingCharacters(in: .whitespaces)
            guard !str.isEmpty, let val = Double(str) else { return }
            let storeVal: Double
            if metric == .weight || metric == .muscleMass {
                storeVal = appState.toKg(val)
            } else {
                storeVal = val
            }
            if metric.validRange.contains(storeVal) {
                result[metric.rawValue] = storeVal
            }
        }

        if parsedMetrics.isEmpty {
            validationMessage = L10n.string("请至少填写一个指标")
            showValidationError = true
            return
        }

        // Validate metric values for both new and editing entries
        for metric in appState.enabledMetrics {
            if let valueStr = metricValues[metric], metricValuesChanged[metric] == true,
               let value = Double(valueStr.trimmingCharacters(in: .whitespaces)) {
                let range = metric.validRange
                if value < range.lowerBound || value > range.upperBound {
                    showValidationError = true
                    validationMessage = String(format: L10n.string("数值验证范围 %@ 在 %@ 到 %@ 之间"), metric.displayName, String(format: "%.0f", range.lowerBound), String(format: "%.0f", range.upperBound))
                    BodyLogHaptics.warning()
                    return
                }
            }
        }

        // Capture whether this is the first entry before saving
        isFirstRecord = entryStore.entries.isEmpty

        if isEditing, var entry = editingEntry {
            entry.metrics = parsedMetrics
            entry.note = note.isEmpty ? nil : note
            entry.recordedAt = recordDate
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
            let savedFilename: String? = photoData.flatMap { PhotoManager.shared.savePhoto($0) }

            let entry = BodyEntry(
                recordedAt: recordDate,
                metrics: parsedMetrics,
                note: note.isEmpty ? nil : note,
                photoFilename: savedFilename
            )
            entryStore.addEntry(entry)
        }

        checkAchievements()
        goalStore.checkAndMarkAchieved(using: entryStore)

        BodyLogHaptics.heavy()

        if isFirstRecord {
            showCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isPresented = false
            }
        } else {
            isPresented = false
        }
    }

    // MARK: - Prefill (Editing)

    private func prefillIfEditing() {
        guard let entry = editingEntry else { return }
        recordDate = entry.recordedAt
        note = entry.note ?? ""
        photoData = entry.loadedPhotoData
        photoWasRemoved = false
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

    // MARK: - Achievements

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

    // MARK: - Image Compression

    private func compressImage(_ image: UIImage, targetSizeKB: Int) -> Data {
        let compression: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: compression) ?? Data()

        if data.count <= targetSizeKB * 1024 {
            return data
        }

        var quality: CGFloat = 0.7
        while quality > 0.1 && data.count > targetSizeKB * 1024 {
            if let compressed = image.jpegData(compressionQuality: quality) {
                data = compressed
            }
            quality -= 0.1
        }

        return data
    }
}

#Preview {
    LogEntryView(isPresented: .constant(true))
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
