// SettingsView.swift
// 设置页

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var showPaywall: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showRemindTimePicker: Bool = false
    @State private var showMetricsPicker: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var showBackupSheet: Bool = false
    @State private var showRestorePicker: Bool = false
    @State private var importResult: String? = nil
    @State private var backupResult: String? = nil
    @State private var showAchievementView: Bool = false
    @State private var showShareCardView: Bool = false
    @State private var exportCSV: String = ""
    @State private var backupData: Data = Data()
    @State private var backupFileURL: URL?
    @State private var isImporting: Bool = false

    /// 从 Bundle 动态读取版本号
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                // Pro banner
                if !appState.isPro {
                    proSection
                }

                // Profile
                Section("个人信息") {
                    LabeledContent("名字") {
                        TextField("昵称", text: $appState.userName)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: appState.userName) { _ in appState.save() }
                    }
                    LabeledContent("身高") {
                        HStack {
                            TextField("--", value: $appState.userHeight, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .onChange(of: appState.userHeight) { _ in appState.save() }
                            Text("cm").foregroundColor(.secondary)
                        }
                    }
                    Picker("性别", selection: $appState.userGender) {
                        ForEach(AppState.Gender.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .onChange(of: appState.userGender) { _ in appState.save() }
                }

                // Units
                Section("单位") {
                    Picker("重量单位", selection: $appState.weightUnit) {
                        ForEach(AppState.WeightUnit.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .onChange(of: appState.weightUnit) { _ in appState.save() }
                }

                // Tracked Metrics
                Section("追踪指标") {
                    Button(action: { showMetricsPicker = true }) {
                        HStack {
                            Text("管理指标")
                            Spacer()
                            Text("\(appState.enabledMetrics.count) 个")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.systemGray3)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Reminder
                Section("每日提醒") {
                    Toggle("开启提醒", isOn: $appState.reminderEnabled)
                        .tint(.bodylogPrimary)
                        .onChange(of: appState.reminderEnabled) { enabled in
                            appState.save()
                            if enabled {
                                if appState.isPro {
                                    let hour = appState.reminderHour
                                    let minute = appState.reminderMinute
                                    NotificationManager.shared.requestAuthorization { granted in
                                        if granted {
                                            NotificationManager.shared.scheduleDailyReminder(hour: hour, minute: minute)
                                        } else {
                                            Task { @MainActor in
                                                appState.reminderEnabled = false
                                                appState.save()
                                            }
                                        }
                                    }
                                } else {
                                    appState.reminderEnabled = false
                                    showPaywall = true
                                }
                            } else {
                                NotificationManager.shared.cancelDailyReminder()
                            }
                        }

                    if appState.reminderEnabled {
                        DatePicker(
                            "提醒时间",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(
                                        bySettingHour: appState.reminderHour,
                                        minute: appState.reminderMinute,
                                        second: 0, of: Date()
                                    ) ?? Date()
                                },
                                set: { newDate in
                                    let c = Calendar.current
                                    appState.reminderHour = c.component(.hour, from: newDate)
                                    appState.reminderMinute = c.component(.minute, from: newDate)
                                    appState.save()
                                    NotificationManager.shared.scheduleDailyReminder(
                                        hour: appState.reminderHour,
                                        minute: appState.reminderMinute
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                // Appearance
                Section("外观") {
                    Picker("主题", selection: $appState.theme) {
                        Text("跟随系统").tag(AppState.AppTheme.system)
                        Text("浅色").tag(AppState.AppTheme.light)
                        Text("深色").tag(AppState.AppTheme.dark)
                    }
                    .onChange(of: appState.theme) { _ in appState.save() }
                }

                // Data
                Section("数据") {
                    Button(action: exportData) {
                        HStack {
                            Label("导出 CSV", systemImage: "arrow.down.doc.fill")
                            Spacer()
                            if !appState.isPro {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(appState.isPro ? .bodylogPrimary : .secondary)
                    
                    if appState.isPro {
                        Button(action: { showImportPicker = true }) {
                            Label("导入 CSV", systemImage: "arrow.up.doc.fill")
                        }
                        .foregroundColor(.bodylogPrimary)
                    }
                    
                    // Backup / Restore (all users)
                    Button(action: createBackup) {
                        Label("备份数据", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.bodylogPrimary)
                    
                    if let result = backupResult {
                        Text(result)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Button(action: { showRestorePicker = true }) {
                        Label("恢复数据", systemImage: "square.and.arrow.down")
                    }
                    .foregroundColor(.orange)

                    // Import / Backup results
                    if let result = importResult {
                        Text(result)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    LabeledContent("总记录数") {
                        Text("\(entryStore.entries.count)")
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("记录天数") {
                        Text("\(entryStore.totalRecordDays) 天")
                            .foregroundColor(.secondary)
                    }
                }

                // Achievements
                Section("成就") {
                    Button(action: { showAchievementView = true }) {
                        HStack {
                            Label("查看成就", systemImage: "trophy.fill")
                            Spacer()
                            Text("\(appState.achievements.count)/\(AchievementType.allCases.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.systemGray3)
                        }
                    }
                    .foregroundColor(.primary)
                }

                    // Share progress (all users)
                    Button(action: { showShareCardView = true }) {
                        Label("分享进度", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.bodylogPrimary)

                // About
                Section("关于") {
                    LabeledContent("版本", value: appVersion)
                    Link(destination: URL(string: "https://pangtongya.github.io/bodylog-privacy/privacy-policy.html")!) {
                        Label("隐私政策", systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isImporting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("导入中...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
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
            handleRestoreResult(result)
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
    }

    // MARK: - Pro Banner

    private var proSection: some View {
        Section {
            Button(action: { showPaywall = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(LinearGradient.bodylogGradient)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("升级到 Pro")
                            .font(.system(size: 15, weight: .semibold))
                        Text("无限目标 · 导出 · 提醒 · 照片记录")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    Text(purchaseManager.formattedPrice)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.bodylogPrimary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    private func exportData() {
        if !appState.isPro {
            showPaywall = true
            return
        }
        let csvString = entryStore.exportCSV()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BodyLog_\(Date().formatted(date: .abbreviated, time: .omitted)).csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportCSV = tempURL.absoluteString
            showExportSheet = true
        } catch {
            backupResult = "导出失败：\(error.localizedDescription)"
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        isImporting = true
        Task {
            let message: String
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    message = "未选择文件"
                    break
                }
                do {
                    let data = try Data(contentsOf: url)
                    guard let csvString = String(data: data, encoding: .utf8) else {
                        message = "导入失败：文件编码不支持"
                        break
                    }
                    let (count, error) = entryStore.importCSV(csvString)
                    if error != nil && count == 0 {
                        message = "导入失败：\(error!)"
                    } else {
                        message = "成功导入 \(count) 条记录" + (error.map { "（\($0)）" } ?? "")
                    }
                } catch {
                    message = "读取文件失败：\(error.localizedDescription)"
                }
            case .failure(let error):
                message = "选择文件失败：\(error.localizedDescription)"
            }
            
            importResult = message
            isImporting = false
        }
    }
    
    // MARK: - Backup / Restore
    
    private func createBackup() {
        let appStateData = (try? JSONEncoder().encode(appState)) ?? Data()
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
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BodyLog_Backup_\(Date().formatted(date: .abbreviated, time: .omitted)).json")
            try data.write(to: tempURL, options: .atomic)
            backupFileURL = tempURL
            showBackupSheet = true
            backupResult = "备份成功（\(String(format: "%.1f", Double(data.count)/1024))KB）"
        } catch {
            backupResult = "备份失败：\(error.localizedDescription)"
        }
    }
    
    private func handleRestoreResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let _ = json["version"] as? String else {
                    backupResult = "恢复失败：无效的备份文件"
                    return
                }
                
                // Restore entries
                if let entriesData = json["entries"] as? Data,
                   let entries = try? JSONDecoder().decode([BodyEntry].self, from: entriesData) {
                    entryStore.entries = entries
                    entryStore.save()
                }
                
                // Restore goals
                if let goalsData = json["goals"] as? Data,
                   let goals = try? JSONDecoder().decode([GoalModel].self, from: goalsData) {
                    goalStore.goals = goals
                    goalStore.save()
                }
                
                // Restore app state
                if let appStateData = json["appState"] as? Data,
                   let restoredState = try? JSONDecoder().decode(AppState.self, from: appStateData) {
                    appState.hasCompletedOnboarding = restoredState.hasCompletedOnboarding
                    appState.userName = restoredState.userName
                    appState.userHeight = restoredState.userHeight
                    appState.userGender = restoredState.userGender
                    appState.weightUnit = restoredState.weightUnit
                    appState.theme = restoredState.theme
                    appState.enabledMetrics = restoredState.enabledMetrics
                    appState.reminderEnabled = restoredState.reminderEnabled
                    appState.reminderHour = restoredState.reminderHour
                    appState.reminderMinute = restoredState.reminderMinute
                    appState.save()
                }
                
                backupResult = "数据恢复成功！"
            } catch {
                backupResult = "恢复失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            backupResult = "选择文件失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - MetricsPickerView

struct MetricsPickerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach([BodyMetricType.MetricCategory.primary, .measurement], id: \.rawValue) { cat in
                    Section(cat.rawValue) {
                        ForEach(BodyMetricType.allCases.filter { $0.category == cat }) { metric in
                            let isEnabled = appState.enabledMetrics.contains(metric)
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if isEnabled {
                                    if appState.enabledMetrics.count > 1 {
                                        appState.enabledMetrics.removeAll { $0 == metric }
                                        appState.save()
                                    }
                                } else {
                                    appState.enabledMetrics.append(metric)
                                    appState.save()
                                }
                            }) {
                                HStack {
                                    Image(systemName: metric.icon)
                                        .foregroundColor(isEnabled ? .bodylogPrimary : .secondary)
                                        .frame(width: 28)
                                    Text(metric.displayName)
                                        .foregroundColor(.primary)
                                    if !metric.unit.isEmpty {
                                        Text("(\(metric.unit))")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if isEnabled {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.bodylogPrimary)
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("追踪指标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { isPresented = false }
                        .foregroundColor(.bodylogPrimary)
                }
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(PurchaseManager.shared)
}
