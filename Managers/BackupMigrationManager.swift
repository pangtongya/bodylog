// BackupMigrationManager.swift
// 备份数据迁移管理器

import Foundation
import os.log

/// 备份数据迁移管理器
/// 负责处理不同版本之间的数据迁移逻辑
@MainActor
final class BackupMigrationManager {

    static let shared = BackupMigrationManager()

    private static let logger = Logger(subsystem: "com.pangtong.formlog", category: "BackupMigrationManager")

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
        Self.logger.info("Migrating from \(fromVersion) to \(toVersion)")

        // 版本相同，无需迁移
        if fromVersion == toVersion {
            return true
        }

        // 不支持的版本
        guard isSupportedVersion(fromVersion) else {
            Self.logger.warning("Unsupported backup version: \(fromVersion)")
            return false
        }

        // 执行迁移
        let success = performMigration(from: fromVersion, to: toVersion, json: &json)

        if success {
            // 更新版本号
            json["version"] = toVersion
            Self.logger.info("Migration successful")
        } else {
            Self.logger.error("Migration failed")
        }

        return success
    }

    // MARK: - Private Methods

    /// 检查版本是否受支持
    private func isSupportedVersion(_ version: String) -> Bool {
        // 目前只支持 1.0 版本
        // 如果将来支持 1.0 -> 1.1 的迁移，需要添加相应逻辑
        return version == "1.0" || version == "1.1" || version == "1.2"
    }

    /// 执行具体的迁移逻辑
    private func performMigration(from fromVersion: String, to toVersion: String, json: inout [String: Any]) -> Bool {
        // 根据版本执行不同的迁移策略

        // 1.0 -> 1.0 无需迁移
        if fromVersion == toVersion {
            return true
        }

        // 未来版本迁移示例：
        // 1.0 -> 1.1: 添加新字段
        if fromVersion == "1.0" && toVersion == "1.1" {
            return migrateFromV1_0(toV1_1: &json)
        }

        // 1.1 -> 1.2: 修改数据结构
        if fromVersion == "1.1" && toVersion == "1.2" {
            return migrateFromV1_1(toV1_2: &json)
        }

        // 1.0 -> 1.2: 跨版本迁移（先到 1.1，再到 1.2）
        if fromVersion == "1.0" && toVersion == "1.2" {
            // 先迁移到 1.1
            guard migrateFromV1_0(toV1_1: &json) else {
                return false
            }
            // 再迁移到 1.2
            return migrateFromV1_1(toV1_2: &json)
        }

        // 未知版本组合
        Self.logger.warning("Unknown migration path: \(fromVersion) -> \(toVersion)")
        return false
    }

    // MARK: - Version-Specific Migrations

    /// 1.0 -> 1.1 迁移
    /// 示例：添加新字段或修改数据结构
    private func migrateFromV1_0(toV1_1 json: inout [String: Any]) -> Bool {
        Self.logger.info("Performing 1.0 -> 1.1 migration")

        // 示例：为 BodyEntry 添加新字段
        if var entriesData = json["entries"] as? Data {
            do {
                let entries = try JSONDecoder().decode([BodyEntry].self, from: entriesData)

                // 为每个条目添加默认值（如果需要）
                for _ in entries.indices {
                    // 例如：添加新字段的默认值
                    // entries[index].someNewField = defaultValue
                }

                // 重新编码
                entriesData = try JSONEncoder().encode(entries)
                json["entries"] = entriesData

                return true
            } catch {
                Self.logger.error("1.0 -> 1.1 migration error: \(error)")
                return false
            }
        }

        return true
    }

    /// 1.1 -> 1.2 迁移
    /// 示例：修改数据结构
    private func migrateFromV1_1(toV1_2 json: inout [String: Any]) -> Bool {
        Self.logger.info("Performing 1.1 -> 1.2 migration")

        // 示例：重命名字段或改变数据结构
        // 实际实现取决于具体的版本差异

        return true
    }

    /// 获取支持的版本列表
    func supportedVersions() -> [String] {
        return ["1.0"] // 未来可以添加更多版本
    }
}