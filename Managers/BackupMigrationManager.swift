// BackupMigrationManager.swift
// 备份数据迁移管理器

import Foundation

/// 备份数据迁移管理器
/// 负责处理不同版本之间的数据迁移逻辑
@MainActor
final class BackupMigrationManager {

    static let shared = BackupMigrationManager()

    /// 当前支持的版本
    static let currentVersion = "1.0"

    private init() {}

    /// 迁移备份数据到当前版本
    /// - Parameters:
    ///   - fromVersion: 备份文件的版本
    ///   - toVersion: 目标版本（通常为 currentVersion）
    ///   - json: 备份数据（ inout 允许修改）
    /// - Returns: 迁移是否成功
    func migrateBackup(from fromVersion: String, to toVersion: String, json: inout [String: Any]) -> Bool {
        print("[BackupMigrationManager] Migrating from \(fromVersion) to \(toVersion)")

        // 版本相同，无需迁移
        if fromVersion == toVersion {
            return true
        }

        // 不支持的版本
        guard isSupportedVersion(fromVersion) else {
            print("[BackupMigrationManager] Unsupported backup version: \(fromVersion)")
            return false
        }

        // 执行迁移
        let success = performMigration(from: fromVersion, to: toVersion, json: &json)

        if success {
            // 更新版本号
            json["version"] = toVersion
            print("[BackupMigrationManager] Migration successful")
        } else {
            print("[BackupMigrationManager] Migration failed")
        }

        return success
    }

    // MARK: - Private Methods

    /// 检查版本是否受支持
    private func isSupportedVersion(_ version: String) -> Bool {
        return supportedVersions().contains(version)
    }

    /// 执行具体的迁移逻辑
    private func performMigration(from fromVersion: String, to toVersion: String, json: inout [String: Any]) -> Bool {
        if fromVersion == toVersion {
            return true
        }

        print("[BackupMigrationManager] Migration from \(fromVersion) to \(toVersion) is not yet implemented")
        return false
    }

    /// 获取支持的版本列表
    func supportedVersions() -> [String] {
        return ["1.0"]
    }
}