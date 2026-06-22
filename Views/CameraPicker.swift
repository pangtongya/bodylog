// CameraPicker.swift
// 相机拍照包装器 — 现代 SwiftUI 实现

import SwiftUI
import UIKit
import AVFoundation
import Photos

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

        // 检查相机是否可用以及授权状态
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                picker.sourceType = .camera
                picker.cameraDevice = .rear
            case .notDetermined:
                // 请求授权，完成后通过 context 切换到相机
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.async {
                            context.coordinator.setCameraMode(true)
                        }
                    }
                }
                picker.sourceType = .photoLibrary
            case .denied, .restricted:
                // 权限被拒绝，提示用户并回退到相册
                context.coordinator.showPermissionDeniedAlert = true
                picker.sourceType = .photoLibrary
            @unknown default:
                picker.sourceType = .photoLibrary
            }
        } else {
            // 设备没有相机，降级为相册
            picker.sourceType = .photoLibrary
        }

        picker.delegate = context.coordinator
        context.coordinator.picker = picker
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        var showPermissionDeniedAlert = false
        weak var picker: UIImagePickerController?

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func setCameraMode(_ useCamera: Bool) {
            if useCamera, let picker = picker {
                picker.sourceType = .camera
                picker.cameraDevice = .rear
            }
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

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            draw(at: .zero)
        }
    }
}
