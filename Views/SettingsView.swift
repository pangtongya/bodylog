// SettingsView.swift
// 设置页

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var showPaywall: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var showRemindTimePicker: Bool = false
    @State private var showMetricsPicker: Bool = false
    @State private var showImportPicker: Bool = false
    @State private var importResult: String? = nil
    @State private var exportCSV: String = ""

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
                                    NotificationManager.shared.requestAuthorization { granted in
                                        if granted {
                                            NotificationManager.shared.scheduleDailyReminder(
                                                hour: appState.reminderHour,
                                                minute: appState.reminderMinute
                                            )
                                        } else {
                                            appState.reminderEnabled = false
                                            appState.save()
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
                        
                        // Import result
                        if let result = importResult {
                            Text(result)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
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

                // About
                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                    Link(destination: URL(string: "https://pangtongya.github.io/bodylog-privacy/privacy-policy.html")!) {
                        Label("隐私政策", systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
                .environmentObject(appState)
                .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportCSV])
        }
        .sheet(isPresented: $showMetricsPicker) {
            MetricsPickerView(isPresented: $showMetricsPicker)
                .environmentObject(appState)
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.commaSeparatedText], allowsMultipleSelection: false) { result in
            handleImportResult(result)
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
        exportCSV = entryStore.exportCSV()
        showExportSheet = true
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let csvString = String(data: data, encoding: .utf8) else {
                    importResult = "导入失败：文件编码不支持"
                    return
                }
                let (count, error) = entryStore.importCSV(csvString)
                if error != nil && count == 0 {
                    importResult = "导入失败：\(error!)"
                } else {
                    importResult = "成功导入 \(count) 条记录" + (error.map { "（\($0)）" } ?? "")
                }
            } catch {
                importResult = "读取文件失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            importResult = "选择文件失败：\(error.localizedDescription)"
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
