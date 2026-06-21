// L10n.swift
// 本地化辅助工具 — 统一管理所有用户可见字符串的翻译

import Foundation

/// 本地化字符串快捷方式
///
/// 用法：
///   Text(L10n.string("记录"))  // 自动根据系统语言返回 "Log" 或 "记录"
///   Text("记录")               // SwiftUI Text 自动本地化（如果 key 在 Localizable.strings 中）
///
/// SwiftUI 的 Text() 和 Label() 会自动查找 Localizable.strings，
/// 但 String 拼接场景需要手动调用 L10n.string()
enum L10n {
    /// 获取本地化字符串
    static func string(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, comment: comment)
    }

    /// 获取本地化字符串（带格式化参数）
    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), args)
    }

    /// 当前语言代码
    static var currentLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "zh-Hans"
    }

    /// 是否为中文环境
    static var isChinese: Bool {
        currentLanguage.hasPrefix("zh")
    }
}
