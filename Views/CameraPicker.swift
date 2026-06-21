// CameraPicker.swift
// 相机拍照包装器 — 现代 SwiftUI 实现

import SwiftUI
import UIKit

/// 相机拍照 UIViewControllerRepresentable
///
/// 说明：UIImagePickerController 仍然是 iOS 上最简单的拍照方式。
/// PhotosPicker 只能从相册选择，不支持拍照。
/// VisionKit 的 DataScannerViewController 不适用于此场景。
/// 在 iOS 17+ 中，SwiftUI 引入了 PhotosPicker 的 .photosPicker 修饰符，
/// 但相机功能仍需 UIImagePickerController 或 AVFoundation 手动实现。
///
/// 当前实现使用 UIImagePickerController + 现代化改进：
/// - 使用 @Environment(\.dismiss) 替代已弃用的 presentationMode
/// - 支持相机不可用时的优雅降级
/// - 图片压缩质量参数化
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    /// 压缩质量（0.0-1.0）
    var compressionQuality: CGFloat = 0.6

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        // 检查相机是否可用（模拟器无相机）
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            // 降级为相册选择
            picker.sourceType = .photoLibrary
        } else {
            picker.sourceType = .camera
            picker.cameraDevice = .rear  // 默认后置摄像头
        }

        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // 修正图片方向并压缩
                let fixedImage = image.fixOrientation()
                if let data = fixedImage.jpegData(compressionQuality: parent.compressionQuality) {
                    parent.imageData = data
                }
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage 方向修正

extension UIImage {
    /// 修正图片方向（拍照时可能根据设备方向产生旋转）
    func fixOrientation() -> UIImage {
        if imageOrientation == .up { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}
