import Foundation
import UIKit

struct BackupItem: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let fileName: String
    let fileSize: Int64
    let entryCount: Int
    let isAutoBackup: Bool

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

@MainActor
final class AutoBackupManager: ObservableObject {
    static let shared = AutoBackupManager()

    @Published var backups: [BackupItem] = []
    @Published var isAutoBackupEnabled: Bool = false
    @Published var autoBackupFrequency: AutoBackupFrequency = .daily
    @Published var lastAutoBackupDate: Date?
    @Published var isBackingUp: Bool = false

    enum AutoBackupFrequency: String, CaseIterable, Codable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"

        var displayName: String {
            switch self {
            case .daily: return L10n.string("每天")
            case .weekly: return L10n.string("每周")
            case .monthly: return L10n.string("每月")
            }
        }
    }

    private let maxAutoBackups = 10
    private let userDefaultsKeyAutoBackup = "autoBackupEnabled"
    private let userDefaultsKeyFrequency = "autoBackupFrequency"
    private let userDefaultsKeyLastBackup = "lastAutoBackupDate"

    private var backupsDirectory: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Backups", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        loadSettings()
        loadBackups()
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        isAutoBackupEnabled = defaults.bool(forKey: userDefaultsKeyAutoBackup)
        if let freqRaw = defaults.string(forKey: userDefaultsKeyFrequency),
           let freq = AutoBackupFrequency(rawValue: freqRaw) {
            autoBackupFrequency = freq
        }
        lastAutoBackupDate = defaults.object(forKey: userDefaultsKeyLastBackup) as? Date
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isAutoBackupEnabled, forKey: userDefaultsKeyAutoBackup)
        defaults.set(autoBackupFrequency.rawValue, forKey: userDefaultsKeyFrequency)
        if let date = lastAutoBackupDate {
            defaults.set(date, forKey: userDefaultsKeyLastBackup)
        }
    }

    func loadBackups() {
        let fm = FileManager.default
        let dir = backupsDirectory

        do {
            let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])

            backups = files.compactMap { url in
                guard url.pathExtension == "zip" else { return nil }
                do {
                    let attrs = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                    let date = attrs.creationDate ?? Date()
                    let size = Int64(attrs.fileSize ?? 0)
                    let name = url.deletingPathExtension().lastPathComponent
                    let isAuto = name.hasPrefix("auto_")
                    let entryCount = extractEntryCount(from: name)

                    return BackupItem(
                        id: UUID(),
                        date: date,
                        fileName: url.lastPathComponent,
                        fileSize: size,
                        entryCount: entryCount,
                        isAutoBackup: isAuto
                    )
                } catch {
                    return nil
                }
            }.sorted(by: { $0.date > $1.date })
        } catch {
            print("[AutoBackupManager] Failed to load backups: \(error)")
            backups = []
        }
    }

    private func extractEntryCount(from name: String) -> Int {
        let parts = name.components(separatedBy: "_")
        for part in parts {
            if part.hasPrefix("e"), let count = Int(part.dropFirst()) {
                return count
            }
        }
        return 0
    }

    func performBackup(isAuto: Bool = false) async -> Bool {
        guard !isBackingUp else { return false }
        isBackingUp = true
        defer { isBackingUp = false }

        do {
            let entryStore = BodyEntryStore.shared
            let goalStore = GoalStore.shared
            let appState = AppState.shared

            let entryCount = entryStore.entries.count

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateStr = dateFormatter.string(from: Date())
            let prefix = isAuto ? "auto_" : "manual_"
            let fileName = "\(prefix)e\(entryCount)_\(dateStr).zip"
            let backupURL = backupsDirectory.appendingPathComponent(fileName)

            var backupData: [String: Any] = [:]

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if let entriesData = try? encoder.encode(entryStore.entries) {
                backupData["entries"] = entriesData
            }

            if let goalsData = try? encoder.encode(goalStore.goals) {
                backupData["goals"] = goalsData
            }

            var appStateDict: [String: Any] = [:]
            appStateDict["userName"] = appState.userName
            appStateDict["userHeight"] = appState.userHeight
            appStateDict["userGender"] = appState.userGender.rawValue
            appStateDict["weightUnit"] = appState.weightUnit.rawValue
            appStateDict["enabledMetrics"] = appState.enabledMetrics.map { $0.rawValue }
            appStateDict["theme"] = appState.theme.rawValue
            appStateDict["accentColor"] = appState.accentColor.rawValue
            backupData["appState"] = appStateDict

            backupData["version"] = "1.0"
            backupData["backupDate"] = Date()
            backupData["isAutoBackup"] = isAuto
            backupData["entryCount"] = entryCount

            let data = try JSONSerialization.data(withJSONObject: backupData)
            try data.write(to: backupURL, options: .atomic)

            if isAuto {
                lastAutoBackupDate = Date()
                saveSettings()
                cleanupOldAutoBackups()
            }

            loadBackups()
            return true
        } catch {
            print("[AutoBackupManager] Backup failed: \(error)")
            return false
        }
    }

    private func cleanupOldAutoBackups() {
        let autoBackups = backups.filter { $0.isAutoBackup }
        guard autoBackups.count > maxAutoBackups else { return }

        let toDelete = Array(autoBackups.suffix(from: maxAutoBackups))
        let fm = FileManager.default

        for backup in toDelete {
            let url = backupsDirectory.appendingPathComponent(backup.fileName)
            try? fm.removeItem(at: url)
        }

        loadBackups()
    }

    func restoreBackup(_ backup: BackupItem) async -> Bool {
        do {
            let url = backupsDirectory.appendingPathComponent(backup.fileName)
            let data = try Data(contentsOf: url)

            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let entriesData = dict["entries"] as? Data {
                let entries = try decoder.decode([BodyEntry].self, from: entriesData)
                BodyEntryStore.shared.entries = entries
                BodyEntryStore.shared.save()
            }

            if let goalsData = dict["goals"] as? Data {
                let goals = try decoder.decode([GoalModel].self, from: goalsData)
                GoalStore.shared.goals = goals
                GoalStore.shared.save()
            }

            if let appStateDict = dict["appState"] as? [String: Any] {
                if let name = appStateDict["userName"] as? String {
                    AppState.shared.userName = name
                }
                if let height = appStateDict["userHeight"] as? Double {
                    AppState.shared.userHeight = height
                }
                if let genderRaw = appStateDict["userGender"] as? String,
                   let gender = AppState.Gender(rawValue: genderRaw) {
                    AppState.shared.userGender = gender
                }
                if let unitRaw = appStateDict["weightUnit"] as? String,
                   let unit = AppState.WeightUnit(rawValue: unitRaw) {
                    AppState.shared.weightUnit = unit
                }
                if let metricsRaw = appStateDict["enabledMetrics"] as? [String] {
                    let metrics = metricsRaw.compactMap { BodyMetricType(rawValue: $0) }
                    AppState.shared.enabledMetrics = metrics
                }
                if let themeRaw = appStateDict["theme"] as? String,
                   let theme = AppTheme(rawValue: themeRaw) {
                    AppState.shared.theme = theme
                }
                if let accentRaw = appStateDict["accentColor"] as? String,
                   let accent = AccentColor(rawValue: accentRaw) {
                    AppState.shared.accentColor = accent
                }
                AppState.shared.save()
            }

            return true
        } catch {
            print("[AutoBackupManager] Restore failed: \(error)")
            return false
        }
    }

    func deleteBackup(_ backup: BackupItem) {
        let fm = FileManager.default
        let url = backupsDirectory.appendingPathComponent(backup.fileName)
        try? fm.removeItem(at: url)
        loadBackups()
    }

    func setAutoBackupEnabled(_ enabled: Bool) {
        isAutoBackupEnabled = enabled
        saveSettings()

        if enabled {
            Task {
                await performBackup(isAuto: true)
            }
        }
    }

    func setAutoBackupFrequency(_ frequency: AutoBackupFrequency) {
        autoBackupFrequency = frequency
        saveSettings()
    }

    func checkAndPerformAutoBackup() {
        guard isAutoBackupEnabled else { return }

        let now = Date()
        let calendar = Calendar.current

        if let last = lastAutoBackupDate {
            var shouldBackup = false

            switch autoBackupFrequency {
            case .daily:
                shouldBackup = !calendar.isDate(last, inSameDayAs: now)
            case .weekly:
                let lastWeek = calendar.component(.weekOfYear, from: last)
                let thisWeek = calendar.component(.weekOfYear, from: now)
                shouldBackup = lastWeek != thisWeek
            case .monthly:
                let lastMonth = calendar.component(.month, from: last)
                let thisMonth = calendar.component(.month, from: now)
                shouldBackup = lastMonth != thisMonth
            }

            if shouldBackup {
                Task {
                    await performBackup(isAuto: true)
                }
            }
        } else {
            Task {
                await performBackup(isAuto: true)
            }
        }
    }

    var latestBackup: BackupItem? {
        backups.first
    }
}
