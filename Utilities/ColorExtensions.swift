// ColorExtensions.swift
// FormLog 品牌色定义

import SwiftUI

extension Color {
    // 主色：绿色系（健康/活力）
    static let formlogPrimary = Color(red: 0.196, green: 0.651, blue: 0.533)
    static let formlogAccent = Color(red: 0.259, green: 0.784, blue: 0.608)

    // 语义色
    static let formlogDecrease = Color(red: 0.220, green: 0.710, blue: 0.494)   // 减少方向（好）
    static let formlogDanger = Color(red: 0.941, green: 0.322, blue: 0.310)     // 危险/增加方向（坏）

    // 图表渐变
    static let chartStart = Color(red: 0.196, green: 0.651, blue: 0.533)
    static let chartEnd = Color(red: 0.118, green: 0.502, blue: 0.408).opacity(0.2)
}

// MARK: - 渐变
extension LinearGradient {
    static let formlogGradient = LinearGradient(
        colors: [.formlogPrimary, .formlogAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let chartGradient = LinearGradient(
        colors: [.chartStart.opacity(0.5), .chartEnd],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - System Colors (SwiftUI wrappers for UIColor adaptive colors)
extension Color {
    static let systemBackground = Color(uiColor: .systemBackground)
    static let systemGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let systemGray3 = Color(uiColor: .systemGray3)
    static let systemGray4 = Color(uiColor: .systemGray4)
    static let systemGray5 = Color(uiColor: .systemGray5)
    static let systemGray6 = Color(uiColor: .systemGray6)
}
