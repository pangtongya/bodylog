// SettingsView.swift
// Settings — Premium Apple HIG-style grouped table

import SwiftUI
import UserNotifications
import os

struct SettingsView: View {
    private let logger = Logger(subsystem: "com.pangtong.formlog", category: "SettingsView")

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    // MARK: - Sheet States

    @State private var showPaywall: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showMetricsPicker: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var showBackupSheet: Bool = false
    @State private var showRestorePicker: Bool = false
    @State private var showAchievementView: Bool = false
    @State private var showShareCardView: Bool = false
    @State private var showCSVTemplate: Bool = false
    @State private var showRestoreConfirm: Bool = false
    @State private var pendingReminderToggle: Bool = false

    // MARK: - Import / Export / Backup States

    @State private var importResult: String? = nil
    @State private var backupResult: String? = nil
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var csvTemplateURL: URL? = nil
    @State private var exportCSV: String = ""
    @State private var backupData: Data = Data()
    @State private var backupFileURL: URL?
    @State private var isImporting: Bool = false
    @State private var importProgress: (current: Int, total: Int) = (0, 0)
    @State private var pendingRestoreURL: URL?
    @State private var pendingRestoreSummary: String? = nil

    // MARK: - Computed

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // MARK: Large Title
                    Text(L10n.string("设置"))
                        .font(.blLargeTitle)
                        .foregroundColor(.formlogTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // MARK: Section 1 — Personal Info
                    settingsSection(L10n.string("个人信息")) {
                        settingsRow(
                            title: L10n.string("名字"),
                            value: appState.userName.isEmpty ? "--" : appState.userName,
                            icon: "person.text.rectangle",
                            chevron: true
                        ) {
                            TextField(L10n.string("昵称"), text: $appState.userName)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                                .font(.blBody)
                                .onChange(of: appState.userName) { _ in appState.save() }
                        }

                        settingsSeparator()

                        settingsRow(
                            title: L10n.string("身高"),
                            value: "\(Int(appState.userHeight)) cm",
                            icon: "ruler",
                            chevron: true
                        ) {
                            HStack(spacing: 4) {
                                TextField("170", value: $appState.userHeight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 50)
                                    .font(.blBody)
                                    .onChange(of: appState.userHeight) { _ in appState.save() }
                                Text(L10n.string("cm"))
                                    .font(.blBody)
                                    .foregroundColor(.formlogTextSecondary)
                            }
                        }

                        settingsSeparator()

                        settingsRow(
                            title: L10n.string("性别"),
                            value: appState.userGender.displayName,
                            icon: "figure.stand",
                            chevron: false
                        ) {
                            Picker("", selection: $appState.userGender) {
                                ForEach(AppState.Gender.allCases, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: appState.userGender) { _ in
                                BodyLogHaptics.light()
                                appState.save()
                            }
                        }
                    }

                    // MARK: Section 2 — Units
                    settingsSection(L10n.string("单位")) {
                        settingsRow(
                            title: L10n.string("重量单位"),
                            value: appState.weightUnit.rawValue,
                            icon: "scalemass",
                            chevron: false
                        ) {
                            Picker("", selection: $appState.weightUnit) {
                                ForEach(AppState.WeightUnit.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: appState.weightUnit) { _ in
                                BodyLogHaptics.light()
                                appState.save()
                            }
                        }
                    }

                    // MARK: Section 3 — Tracked Metrics
                    settingsSection(L10n.string("追踪指标")) {
                        Button(action: { showMetricsPicker = true }) {
                            settingsRowContent(
                                title: L10n.string("管理指标"),
                                value: "\(appState.enabledMetrics.count) " + L10n.string("个"),
                                icon: "chart.bar.doc.horizontal",
                                chevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Section 4 — Daily Reminder
                    settingsSection(L10n.string("每日提醒")) {
                        // Toggle row
                        HStack(spacing: 0) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.formlogTextSecondary)
                                .frame(width: 30)

                            Text(L10n.string("开启提醒"))
                                .font(.blBody)
                                .foregroundColor(.formlogTextPrimary)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { appState.reminderEnabled },
                                set: { newValue in
                                    BodyLogHaptics.light()
                                    if newValue {
                                        if appState.isPro {
                                            appState.reminderEnabled = true
                                            appState.save()
                                            let hour = appState.reminderHour
                                            let minute = appState.reminderMinute
                                            NotificationManager.shared.requestAuthorization { granted in
                                                Task { @MainActor in
                                                    if granted {
                                                        NotificationManager.shared.scheduleDailyReminder(hour: hour, minute: minute)
                                                        AchievementManager.shared.markReminderSet()
                                                    } else {
                                                        appState.reminderEnabled = false
                                                        appState.save()
                                                        notificationStatus = .denied
                                                    }
                                                }
                                            }
                                        } else {
                                            // Don't change the setting yet — show paywall and let purchase handler enable it
                                            pendingReminderToggle = true
                                            showPaywall = true
                                        }
                                    } else {
                                        appState.reminderEnabled = false
                                        appState.save()
                                        NotificationManager.shared.cancelDailyReminder()
                                    }
                                }
                            ))
                                .labelsHidden()
                                .tint(.formlogPrimary)
                        }
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())

                        // Pro hint for free users
                        if !appState.isPro {
                            HStack(spacing: 6) {
                                Spacer()
                                Text(L10n.string("Pro 功能"))
                                    .font(.blCaption1)
                                    .foregroundColor(.formlogTextTertiary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                            .padding(.bottom, 4)
                        }

                        // Permission denied warning
                        if notificationStatus == .denied {
                            settingsSeparator()
                            Button(action: openSettings) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(Color.formlogWarning.opacity(0.12))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.formlogWarning)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L10n.string("通知权限已关闭"))
                                            .font(.blFootnoteMedium)
                                            .foregroundColor(.formlogTextPrimary)
                                        Text(L10n.string("点击前往系统设置开启"))
                                            .font(.blCaption1)
                                            .foregroundColor(.formlogTextSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 16))
                                        .foregroundColor(.formlogWarning)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }

                        // Time picker (only when enabled)
                        if appState.reminderEnabled {
                            settingsSeparator()
                            reminderTimeRow()
                        }
                    }

                    // MARK: Section 5 — Data
                    settingsSection(L10n.string("数据")) {
                        // Export CSV
                        Button(action: exportData) {
                            settingsRowContent(
                                title: L10n.string("导出 CSV"),
                                value: nil,
                                icon: "square.and.arrow.up",
                                chevron: true,
                                locked: !appState.isPro
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(entryStore.entries.isEmpty)

                        // Import CSV (Pro only)
                        settingsSeparator()
                        Button(action: {
                            if !appState.isPro {
                                showPaywall = true
                            } else if !isImporting {
                                showImportPicker = true
                            }
                        }) {
                            settingsRowContent(
                                title: L10n.string("导入 CSV"),
                                value: nil,
                                icon: "square.and.arrow.down",
                                chevron: true,
                                locked: !appState.isPro
                            )
                        }
                        .buttonStyle(.plain)

                        // Backup
                        settingsSeparator()
                        Button(action: createBackup) {
                            settingsRowContent(
                                title: L10n.string("备份数据"),
                                value: nil,
                                icon: "externaldrive.badge.plus",
                                chevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(entryStore.entries.isEmpty)

                        // Restore
                        settingsSeparator()
                        Button(action: { showRestorePicker = true }) {
                            settingsRowContent(
                                title: L10n.string("恢复数据"),
                                value: nil,
                                icon: "arrow.triangle.2.circlepath",
                                chevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        // Result messages
                        if let result = importResult {
                            settingsSeparator()
                            resultInfoRow(text: result)
                        }
                        if let result = backupResult {
                            settingsSeparator()
                            resultInfoRow(text: result)
                        }

                        // Total entries
                        settingsSeparator()
                        settingsRowContent(
                            title: L10n.string("总记录数"),
                            value: "\(entryStore.entries.count)",
                            icon: "number.circle",
                            chevron: false
                        )

                        // Record days
                        settingsSeparator()
                        settingsRowContent(
                            title: L10n.string("记录天数"),
                            value: String(format: L10n.string("%d 天"), entryStore.totalRecordDays),
                            icon: "calendar",
                            chevron: false
                        )
                    }

                    // MARK: Section 6 — Achievements
                    settingsSection(L10n.string("成就")) {
                        Button(action: { showAchievementView = true }) {
                            settingsRowContent(
                                title: L10n.string("查看成就"),
                                value: "\(appState.achievements.count)/\(AchievementType.allCases.count)",
                                icon: "trophy.fill",
                                chevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Section 7 — Share
                    settingsSection(L10n.string("分享")) {
                        Button(action: { showShareCardView = true }) {
                            settingsRowContent(
                                title: L10n.string("分享进度"),
                                value: nil,
                                icon: "square.and.arrow.up",
                                chevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Section 8 — Pro
                    settingsSection(L10n.string("Pro")) {
                        Button(action: {
                            if !appState.isPro { showPaywall = true }
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(
                                            LinearGradient(
                                                colors: [.formlogPrimary, .formlogAccent],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L10n.string("解锁Pro版本"))
                                        .font(.blBodySemibold)
                                        .foregroundColor(.formlogTextPrimary)
                                    Text(L10n.string("解锁全部高级功能"))
                                        .font(.blFootnote)
                                        .foregroundColor(.formlogTextSecondary)
                                }

                                Spacer()

                                if appState.isPro {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.formlogPrimary)
                                        Text(L10n.string("已解锁"))
                                            .font(.blFootnoteMedium)
                                            .foregroundColor(.formlogPrimary)
                                    }
                                } else {
                                    chevronImage
                                }
                            }
                            .frame(height: 56)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: Section 9 — About
                    settingsSection(L10n.string("关于")) {
                        settingsRowContent(
                            title: L10n.string("版本"),
                            value: appVersion,
                            icon: "info.circle",
                            chevron: false
                        )

                        settingsSeparator()

                        if let url = URL(string: "https://pangtongya.github.io/bodylog/privacy.html") {
                            Link(destination: url) {
                                settingsRowContent(
                                    title: L10n.string("隐私政策"),
                                    value: nil,
                                    icon: "hand.raised",
                                    chevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Footer
                    Text(L10n.string("用心守护你的健康"))
                        .font(.blCaption1)
                        .foregroundColor(.formlogTextTertiary)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
            }
            .background(Color.formlogBgGrouped)
            .navigationBarHidden(true)
            .onAppear {
                checkNotificationStatus()
            }
            .onChange(of: appState.isPro) { isPro in
                if isPro && pendingReminderToggle {
                    pendingReminderToggle = false
                    appState.reminderEnabled = true
                    appState.save()
                    let hour = appState.reminderHour
                    let minute = appState.reminderMinute
                    NotificationManager.shared.requestAuthorization { granted in
                        Task { @MainActor in
                            if granted {
                                NotificationManager.shared.scheduleDailyReminder(hour: hour, minute: minute)
                                AchievementManager.shared.markReminderSet()
                            } else {
                                appState.reminderEnabled = false
                                appState.save()
                                notificationStatus = .denied
                            }
                        }
                    }
                }
            }
            .overlay {
                if isImporting {
                    importingOverlay
                }
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // If paywall closed without purchasing, clear pending reminder toggle
            if pendingReminderToggle {
                pendingReminderToggle = false
            }
        }) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = URL(string: exportCSV) {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showMetricsPicker) {
            MetricsPickerView(isPresented: $showMetricsPicker)
                .environmentObject(appState)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: $showBackupSheet) {
            if let url = backupFileURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(isPresented: $showRestorePicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            handleRestorePickerResult(result)
        }
        .alert(L10n.string("确认恢复数据"), isPresented: $showRestoreConfirm) {
            Button(L10n.string("取消"), role: .cancel) { }
            Button(L10n.string("确认恢复"), role: .destructive) {
                performRestore()
            }
        } message: {
            if let summary = pendingRestoreSummary {
                Text(summary + "\n\n" + L10n.string("恢复将覆盖当前所有数据，此操作不可撤销。"))
            } else {
                Text(L10n.string("恢复将覆盖当前所有数据，此操作不可撤销。"))
            }
        }
        .sheet(isPresented: $showAchievementView) {
            AchievementView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
        .sheet(isPresented: $showShareCardView) {
            ShareCardView()
                .environmentObject(appState)
                .environmentObject(entryStore)
        }
        .sheet(isPresented: $showCSVTemplate) {
            if let url = csvTemplateURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Theme Display Name

    private var themeDisplayName: String {
        switch appState.theme {
        case .system: return L10n.string("跟随系统")
        case .light: return L10n.string("浅色")
        case .dark: return L10n.string("深色")
        }
    }

    // MARK: - Chevron Image

    private var chevronImage: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.formlogTextQuaternary)
    }

    // MARK: - Section Container

    /// iOS Settings-style grouped section: section header label + card container
    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header — 13pt medium, uppercase, secondary color
            Text(title.uppercased())
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            // Card container
            VStack(spacing: 0) {
                content()
            }
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Settings Row (44pt height, icon + title + value + chevron)

    private func settingsRow<Content: View>(
        title: String,
        value: String?,
        icon: String,
        chevron: Bool,
        locked: Bool = false,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .frame(width: 30)

            Text(title)
                .font(.blBody)
                .foregroundColor(.formlogTextPrimary)

            Spacer()

            HStack(spacing: 6) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.formlogTextTertiary)
                }

                if let value = value, !value.isEmpty {
                    Text(value)
                        .font(.blBody)
                        .foregroundColor(.formlogTextSecondary)
                }

                trailing()

                if chevron {
                    chevronImage
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    /// Convenience for rows that are pure content (no trailing closure)
    private func settingsRowContent(
        title: String,
        value: String?,
        icon: String,
        chevron: Bool,
        locked: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .frame(width: 30)

            Text(title)
                .font(.blBody)
                .foregroundColor(.formlogTextPrimary)

            Spacer()

            HStack(spacing: 6) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.formlogTextTertiary)
                }

                if let value = value, !value.isEmpty {
                    Text(value)
                        .font(.blBody)
                        .foregroundColor(.formlogTextSecondary)
                }

                if chevron {
                    chevronImage
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    // MARK: - Separator

    /// Inset separator — left-aligned 16px from card edge, full-width within card
    private func settingsSeparator() -> some View {
        Rectangle()
            .fill(Color.formlogSeparator)
            .frame(height: 0.5)
            .padding(.leading, 62) // 16 horizontal padding + 30 icon + 16 spacing
    }

    // MARK: - Reminder Time Row

    private func reminderTimeRow() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .frame(width: 30)

            Text(L10n.string("提醒时间"))
                .font(.blBody)
                .foregroundColor(.formlogTextPrimary)

            Spacer()

            DatePicker(
                "",
                selection: Binding(
                    get: {
                        Calendar.current.date(
                            bySettingHour: appState.reminderHour,
                            minute: appState.reminderMinute,
                            second: 0,
                            of: Date()
                        ) ?? Date()
                    },
                    set: { newValue in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        let hour = components.hour ?? 8
                        let minute = components.minute ?? 0
                        appState.reminderHour = hour
                        appState.reminderMinute = minute
                        appState.save()
                        if appState.reminderEnabled {
                            Task { @MainActor in
                                NotificationManager.shared.scheduleDailyReminder(hour: hour, minute: minute)
                            }
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    // MARK: - Result Info Row

    private func resultInfoRow(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .frame(width: 30)

            Text(text)
                .font(.blFootnote)
                .foregroundColor(.formlogTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Importing Overlay

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text(L10n.string("导入中..."))
                    .font(.blBodyMedium)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self.notificationStatus = status
            }
        }
    }

    // MARK: - CSV Template

    private func exportCSVTemplate() {
        let csvString = BodyEntryStore.generateCSVTemplate()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FormLog_CSV_格式示例.csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            csvTemplateURL = tempURL
            showCSVTemplate = true
        } catch {
            importResult = String(format: L10n.string("导出失败：%@"), error.localizedDescription)
        }
    }

    // MARK: - Actions

    private func exportData() {
        if !appState.isPro {
            showPaywall = true
            return
        }
        let csvString = entryStore.exportCSV()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FormLog_\(Date().formatted(date: .abbreviated, time: .omitted)).csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportCSV = tempURL.absoluteString
            showExportSheet = true
        } catch {
            backupResult = String(format: L10n.string("导出失败：%@"), error.localizedDescription)
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        isImporting = true
        importProgress = (0, 0)
        Task {
            let message: String
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    message = L10n.string("未选择文件")
                    isImporting = false
                    break
                }
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let data = try Data(contentsOf: url)
                    guard let csvString = String(data: data, encoding: .utf8) else {
                        message = L10n.string("导入失败：文件编码不支持，请将CSV文件转换为UTF-8编码")
                        break
                    }
                    let (count, error) = entryStore.importCSV(csvString) { current, total in
                            DispatchQueue.main.async {
                                importProgress = (current, total)
                            }
                        }
                    if count == 0, let err = error {
                        message = String(format: L10n.string("导入失败：%@"), err)
                    } else if count > 0 {
                        if let err = error {
                            message = String(format: L10n.string("成功导入 %d 条记录\n\n以下行被跳过：\n%@"), count, err)
                        } else {
                            message = String(format: L10n.string("成功导入 %d 条记录"), count)
                        }
                    } else {
                        message = L10n.string("未导入任何记录")
                    }
                } catch {
                    message = String(format: L10n.string("读取文件失败：%@"), error.localizedDescription)
                }
                isImporting = false
            case .failure(let error):
                message = String(format: L10n.string("选择文件失败：%@"), error.localizedDescription)
                isImporting = false
            }

            importResult = message
        }
    }

    // MARK: - Backup / Restore

    private func createBackup() {
        let appStateData = appState.encodeForBackup()
        let entriesData = (try? JSONEncoder().encode(entryStore.entries)) ?? Data()
        let goalsData = (try? JSONEncoder().encode(goalStore.goals)) ?? Data()
        let backupDict: [String: Any] = [
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appState": appStateData,
            "entries": entriesData,
            "goals": goalsData
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: backupDict, options: [.prettyPrinted, .sortedKeys])
            backupData = data
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("FormLog_Backup_\(Date().formatted(date: .abbreviated, time: .omitted)).json")
            try data.write(to: tempURL, options: .atomic)
            backupFileURL = tempURL
            showBackupSheet = true
            backupResult = String(format: L10n.string("备份成功（%.1f KB）"), Double(data.count)/1024)
        } catch {
            backupResult = String(format: L10n.string("备份失败：%@"), error.localizedDescription)
        }
    }

    private func handleRestorePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    backupResult = L10n.string("无法读取备份文件信息")
                    return
                }
                var summaryParts: [String] = []
                if let entriesArray = json["entries"] as? [[String: Any]] {
                    let entriesData = try? JSONSerialization.data(withJSONObject: entriesArray)
                    if let entriesData = entriesData {
                        let entries: [BodyEntry]
                        do {
                            entries = try JSONDecoder().decode([BodyEntry].self, from: entriesData)
                        } catch {
                            logger.error("Failed to decode entries for restore preview: \(error.localizedDescription)")
                            entries = []
                        }
                        if !entries.isEmpty {
                            summaryParts.append(String(format: L10n.string("记录数量：%d"), entries.count))
                            let dates = entries.map { $0.recordedAt }.sorted()
                            if let earliest = dates.first, let latest = dates.last {
                                let fmt = ISO8601DateFormatter()
                                summaryParts.append(String(format: L10n.string("日期范围：%@ 至 %@"),
                                    String(fmt.string(from: earliest).prefix(10)),
                                    String(fmt.string(from: latest).prefix(10))))
                            }
                        }
                    }
                }
                if let exportDate = json["exportDate"] as? String {
                    summaryParts.append(String(format: L10n.string("备份时间：%@"), exportDate))
                }
                pendingRestoreSummary = summaryParts.isEmpty ? nil : summaryParts.joined(separator: "\n")
                pendingRestoreURL = url
                showRestoreConfirm = true
            } catch {
                backupResult = String(format: L10n.string("读取备份文件失败：%@"), error.localizedDescription)
            }
        case .failure(let error):
            backupResult = String(format: L10n.string("选择文件失败：%@"), error.localizedDescription)
        }
    }

    private func performRestore() {
        guard let url = pendingRestoreURL else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let backupVersion = json["version"] as? String else {
                backupResult = L10n.string("恢复失败：无效的备份文件")
                return
            }

            let currentVersion = "1.0"
            if backupVersion != currentVersion {
                guard BackupMigrationManager.shared.migrateBackup(from: backupVersion, to: currentVersion, json: &json) else {
                    backupResult = String(format: L10n.string("恢复失败：不支持从版本 %@ 迁移到当前版本"), backupVersion)
                    return
                }
            }

            if let entriesArray = json["entries"] as? [[String: Any]] {
                let entriesData = try? JSONSerialization.data(withJSONObject: entriesArray)
                if let entriesData = entriesData {
                    let entries: [BodyEntry]
                    do {
                        entries = try JSONDecoder().decode([BodyEntry].self, from: entriesData)
                    } catch {
                        logger.error("Failed to decode entries from backup: \(error.localizedDescription)")
                        entries = []
                    }
                    if !entries.isEmpty {
                        entryStore.replaceEntries(entries)
                    }
                }
            }

            if let goalsArray = json["goals"] as? [[String: Any]] {
                let goalsData = try? JSONSerialization.data(withJSONObject: goalsArray)
                if let goalsData = goalsData {
                    let goals: [GoalModel]
                    do {
                        goals = try JSONDecoder().decode([GoalModel].self, from: goalsData)
                    } catch {
                        logger.error("Failed to decode goals from backup: \(error.localizedDescription)")
                        goals = []
                    }
                    if !goals.isEmpty {
                        goalStore.goals = goals
                        goalStore.save()
                    }
                }
            }

            if let appStateDict = json["appState"] as? [String: Any] {
                let appStateData = try? JSONSerialization.data(withJSONObject: appStateDict)
                if let appStateData = appStateData {
                    if !appState.restoreFromBackup(appStateData) {
                        backupResult = L10n.string("恢复失败：应用状态数据无效")
                        pendingRestoreURL = nil
                        return
                    }
                }
            }

            backupResult = L10n.string("数据恢复成功！")
            pendingRestoreURL = nil
        } catch {
            backupResult = String(format: L10n.string("恢复失败：%@"), error.localizedDescription)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
        .environmentObject(PurchaseManager.shared)
}
