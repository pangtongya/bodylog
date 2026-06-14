// PhotoManager.swift
// 照片文件管理器 - 管理照片的本地文件存储

import UIKit

/// 照片文件管理器
/// 职责：
/// 1. 把 Data 照片保存到 Documents/Photos/ 目录
/// 2. 根据 filename 加载照片 Data
/// 3. 删除指定照片文件
final class PhotoManager: @unchecked Sendable {
    
    static let shared = PhotoManager()
    private let fileManager = FileManager.default
    
    /// 照片存放目录: Documents/BodyLogPhotos/
    private var photosDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("BodyLogPhotos", isDirectory: true)
    }
    
    private init() {
        ensureDirectoryExists()
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
            print("[PhotoManager] Save error: \(error)")
            return nil
        }
    }
    
    /// 根据文件名加载照片数据
    func loadPhoto(filename: String) -> Data? {
        let url = photosDirectory.appendingPathComponent(filename)
        do {
            return try Data(contentsOf: url)
        } catch {
            print("[PhotoManager] Load error for \(filename): \(error)")
            return nil
        }
    }
    
    /// 删除指定照片文件
    func deletePhoto(filename: String) {
        let url = photosDirectory.appendingPathComponent(filename)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            print("[PhotoManager] Delete error for \(filename): \(error)")
        }
    }
    
    /// 迁移旧数据：把 photoData (Data?) 转换为 photoFilename (String?)
    /// 返回迁移后的文件名，或 nil 如果无需迁移
    func migrate(photoData: Data?) -> String? {
        guard let data = photoData else { return nil }
        // 数据太小，可能是无效数据
        guard data.count > 1000 else { return nil }
        return savePhoto(data)
    }
    
    // MARK: - Private
    
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            do {
                try fileManager.createDirectory(at: photosDirectory,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
            } catch {
                print("[PhotoManager] Failed to create directory: \(error)")
            }
        }
    }
}
