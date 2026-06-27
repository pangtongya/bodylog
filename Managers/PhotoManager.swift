// PhotoManager.swift
// 照片文件管理器 - 管理照片的本地文件存储

import UIKit
import os.log

/// 照片文件管理器
/// 职责：
/// 1. 把 Data 照片保存到 Documents/Photos/ 目录
/// 2. 根据 filename 加载照片 Data
/// 3. 删除指定照片文件
final class PhotoManager: @unchecked Sendable {

    private static let logger = Logger(subsystem: "com.pangtong.formlog", category: "PhotoManager")

    static let shared = PhotoManager()
    private let fileManager = FileManager.default

    /// 照片存放目录: Documents/FormLogPhotos/
    private var photosDirectory: URL {
        let docsURL: URL
        if let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            docsURL = url
        } else {
            let tmp = NSTemporaryDirectory()
            docsURL = URL(fileURLWithPath: tmp)
        }
        return docsURL.appendingPathComponent("FormLogPhotos", isDirectory: true)
    }

    // MARK: - Memory Cache

    /// 内存缓存配置
    private struct CacheConfig {
        static let maxCacheSize = 50 // 最大缓存照片数量
        static let maxMemoryBytes: Int64 = 100 * 1024 * 1024 // 最大内存使用 100MB
    }

    /// 内存缓存（使用 NSCache）
    private let memoryCache = NSCache<NSString, NSData>()

    private init() {
        ensureDirectoryExists()
        setupCache()
    }

    private func setupCache() {
        memoryCache.countLimit = CacheConfig.maxCacheSize
        // 设置总成本限制（使用内存字节数作为成本）
        memoryCache.totalCostLimit = Int(CacheConfig.maxMemoryBytes)

        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
        Self.logger.info("Memory warning, cache cleared")
    }
    
    // MARK: - Public API
    
    /// 保存照片数据到文件，返回文件名
    func savePhoto(_ data: Data) -> String? {
        ensureDirectoryExists()
        let filename = "\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            Self.logger.error("Photo save error: \(error)")
            return nil
        }
    }
    
    /// 根据文件名加载照片数据
    func loadPhoto(filename: String) -> Data? {
        // Validate filename to prevent path traversal attacks
        guard !filename.contains("/") && !filename.contains("..") else {
            Self.logger.error("Invalid filename rejected: \(filename)")
            return nil
        }
        let url = photosDirectory.appendingPathComponent(filename)
        // Ensure the resolved path is within photosDirectory
        guard url.path.hasPrefix(photosDirectory.path) else {
            Self.logger.error("Path traversal attempt detected: \(filename)")
            return nil
        }

        // 尝试从内存缓存读取
        let cacheKey = filename as NSString
        if let cachedData = memoryCache.object(forKey: cacheKey) {
            return Data(referencing: cachedData)
        }

        // 从文件系统加载
        do {
            let data = try Data(contentsOf: url)

            // 缓存到内存
            let nsData = data as NSData
            memoryCache.setObject(nsData, forKey: cacheKey, cost: data.count)

            return data
        } catch {
            Self.logger.error("Photo load error for \(filename): \(error)")
            return nil
        }
    }

    /// 从缓存中移除指定照片
    func removePhotoFromCache(filename: String) {
        let cacheKey = filename as NSString
        memoryCache.removeObject(forKey: cacheKey)
    }

    /// 清空所有缓存
    func clearCache() {
        memoryCache.removeAllObjects()
        Self.logger.info("Memory cache cleared")
    }

    /// 获取缓存统计信息
    func getCacheStats() -> (count: Int, totalSize: Int64) {
        // NSCache 不直接提供遍历方法
        return (0, 0)
    }
    
    /// 删除指定照片文件
    func deletePhoto(filename: String) {
        // 从缓存中移除
        removePhotoFromCache(filename: filename)

        let url = photosDirectory.appendingPathComponent(filename)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            Self.logger.error("Photo delete error for \(filename): \(error)")
        }
    }

    // MARK: - Private
    
    /// 计算照片目录总大小（字节）
    func calculateTotalStorage() -> Int64 {
        var totalSize: Int64 = 0
        do {
            let files = try fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        } catch {
            Self.logger.error("Calculate storage error: \(error)")
        }
        return totalSize
    }
    
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            do {
                try fileManager.createDirectory(at: photosDirectory,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
            } catch {
                Self.logger.error("Failed to create directory: \(error)")
            }
        }
    }
}
