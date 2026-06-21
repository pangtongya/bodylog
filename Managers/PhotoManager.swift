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
