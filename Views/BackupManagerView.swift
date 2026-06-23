import SwiftUI

struct BackupManagerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var autoBackupManager: AutoBackupManager
    @Environment(\.dismiss) var dismiss

    @State private var showDeleteConfirm: Bool = false
    @State private var backupToDelete: BackupItem?
    @State private var showRestoreConfirm: Bool = false
    @State private var backupToRestore: BackupItem?
    @State private var showSuccessToast: Bool = false
    @State private var successMessage: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string("自动备份"))
                                    .font(.system(size: 16, weight: .semibold))
                                Text(L10n.string("开启后自动备份你的数据"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { autoBackupManager.isAutoBackupEnabled },
                                set: { newValue in
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    autoBackupManager.setAutoBackupEnabled(newValue)
                                }
                            ))
                            .labelsHidden()
                        }

                        if autoBackupManager.isAutoBackupEnabled {
                            Picker(L10n.string("备份频率"), selection: Binding(
                                get: { autoBackupManager.autoBackupFrequency },
                                set: { newValue in
                                    autoBackupManager.setAutoBackupFrequency(newValue)
                                }
                            )) {
                                ForEach(AutoBackupManager.AutoBackupFrequency.allCases, id: \.self) { freq in
                                    Text(freq.displayName).tag(freq)
                                }
                            }
                            .pickerStyle(.menu)

                            if let lastDate = autoBackupManager.lastAutoBackupDate {
                                HStack {
                                    Text(L10n.string("上次备份"))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatRelativeDate(lastDate))
                                        .foregroundColor(.secondary)
                                }
                                .font(.system(size: 13))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L10n.string("自动备份设置"))
                } footer: {
                    Text(L10n.string("最多保留 10 个自动备份，旧备份将自动删除"))
                        .font(.system(size: 12))
                }

                Section {
                    Button(action: {
                        Task {
                            await performManualBackup()
                        }
                    }) {
                        HStack {
                            if autoBackupManager.isBackingUp {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.formlogPrimary)
                            }
                            Text(autoBackupManager.isBackingUp ? L10n.string("备份中...") : L10n.string("立即备份"))
                                .foregroundColor(autoBackupManager.isBackingUp ? .secondary : .formlogPrimary)
                        }
                    }
                    .disabled(autoBackupManager.isBackingUp)
                } header: {
                    Text(L10n.string("手动备份"))
                }

                Section {
                    if autoBackupManager.backups.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text(L10n.string("暂无备份"))
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        ForEach(autoBackupManager.backups) { backup in
                            backupRow(backup)
                        }
                    }
                } header: {
                    HStack {
                        Text(L10n.string("备份历史"))
                        Spacer()
                        if !autoBackupManager.backups.isEmpty {
                            Text("\(autoBackupManager.backups.count)")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13))
                        }
                    }
                }
            }
            .navigationTitle(L10n.string("备份管理"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .overlay {
                if showSuccessToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.systemBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                        Spacer()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
                }
            }
            .alert(L10n.string("删除备份"), isPresented: $showDeleteConfirm) {
                Button(L10n.string("取消"), role: .cancel) { }
                Button(L10n.string("删除"), role: .destructive) {
                    if let backup = backupToDelete {
                        autoBackupManager.deleteBackup(backup)
                    }
                }
            } message: {
                Text(L10n.string("确定要删除这个备份吗？此操作不可撤销。"))
            }
            .alert(L10n.string("恢复备份"), isPresented: $showRestoreConfirm) {
                Button(L10n.string("取消"), role: .cancel) { }
                Button(L10n.string("恢复"), role: .destructive) {
                    if let backup = backupToRestore {
                        Task {
                            await restoreBackup(backup)
                        }
                    }
                }
            } message: {
                Text(L10n.string("恢复备份将覆盖当前所有数据，确定继续吗？"))
            }
        }
    }

    private func backupRow(_ backup: BackupItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backup.isAutoBackup ? Color.formlogPrimary.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: backup.isAutoBackup ? "clock.arrow.circlepath" : "archivebox.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(backup.isAutoBackup ? .formlogPrimary : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.formattedDate)
                    .font(.system(size: 15, weight: .medium))
                HStack(spacing: 8) {
                    Text("\(backup.entryCount) \(L10n.string("条记录"))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryLabel)
                    Text(backup.formattedSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if backup.isAutoBackup {
                        Text("·")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryLabel)
                        Text(L10n.string("自动"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.formlogPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.formlogPrimary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            Menu {
                Button(action: {
                    backupToRestore = backup
                    showRestoreConfirm = true
                }) {
                    Label(L10n.string("恢复"), systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive, action: {
                    backupToDelete = backup
                    showDeleteConfirm = true
                }) {
                    Label(L10n.string("删除"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func performManualBackup() async {
        let success = await autoBackupManager.performBackup(isAuto: false)
        if success {
            showSuccess(message: L10n.string("备份成功"))
        }
    }

    private func restoreBackup(_ backup: BackupItem) async {
        let success = await autoBackupManager.restoreBackup(backup)
        if success {
            showSuccess(message: L10n.string("恢复成功"))
        }
    }

    private func showSuccess(message: String) {
        successMessage = message
        withAnimation { showSuccessToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSuccessToast = false }
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    BackupManagerView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore.shared)
        .environmentObject(GoalStore.shared)
        .environmentObject(AutoBackupManager())
}
