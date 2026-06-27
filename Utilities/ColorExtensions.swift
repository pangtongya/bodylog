// ColorExtensions.swift
// BodyLog Design System — Apple HIG (Dark Mode Support)

import SwiftUI
import UIKit

// MARK: - Color Design Tokens

extension Color {

    // MARK: - Primary Brand Colors

    /// BodyLog primary green — Apple Green #30D158
    static let formlogPrimary = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let formlogAccent = Color(red: 0.0, green: 0.478, blue: 1.0)

    /// Primary at 0.08 opacity — subtle tinted backgrounds
    static let formlogPrimaryPale = Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.08)
    /// Primary at 0.15 opacity — highlighted surfaces
    static let formlogPrimarySoft = Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.15)

    // MARK: - Metric Accent Colors (Apple System Colors)

    /// Weight metric — Green #30D158
    static let formlogWeight = Color(red: 0.188, green: 0.820, blue: 0.345)
    /// Body Fat metric — Blue #0A84FF
    static let formlogBodyFat = Color(red: 0.039, green: 0.518, blue: 1.0)
    /// Muscle metric — Orange #FF9F0A
    static let formlogMuscle = Color(red: 1.0, green: 0.624, blue: 0.039)
    /// BMI metric — Red #FF453A
    static let formlogBMI = Color(red: 1.0, green: 0.271, blue: 0.227)
    /// Waist metric — Purple #BF5AF2
    static let formlogWaist = Color(red: 0.749, green: 0.353, blue: 0.949)
    /// Chest metric — Cyan #64D2FF
    static let formlogChest = Color(red: 0.392, green: 0.824, blue: 1.0)

    // MARK: - Semantic Colors

    static let formlogDecrease = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let formlogDanger = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let formlogWarning = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let formlogBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let formlogOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let formlogPurple = Color(red: 0.686, green: 0.322, blue: 0.871)
    static let formlogPink = Color(red: 1.0, green: 0.176, blue: 0.333)

    // MARK: - Text Colors (Apple HIG Adaptive)

    /// Primary label — light: #1C1C1E, dark: #FFFFFF
    static let formlogTextPrimary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0)
    })

    /// Secondary label — light: rgba(60,60,67,0.55), dark: rgba(235,235,245,0.55)
    static let formlogTextSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.55)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.55)
    })

    /// Tertiary label — light: rgba(60,60,67,0.28), dark: rgba(235,235,245,0.28)
    static let formlogTextTertiary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.28)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.28)
    })

    /// Quaternary label — light: rgba(60,60,67,0.15), dark: rgba(235,235,245,0.15)
    static let formlogTextQuaternary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.15)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.15)
    })

    // MARK: - Background Colors (Apple HIG Adaptive)

    static let formlogBgGrouped = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            : UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1.0)
    })

    static let formlogBgSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.090, green: 0.090, blue: 0.098, alpha: 1.0)
            : UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1.0)
    })

    static let formlogBgTertiary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.141, green: 0.141, blue: 0.153, alpha: 1.0)
            : UIColor(red: 0.898, green: 0.898, blue: 0.918, alpha: 1.0)
    })

    // MARK: - Card / Surface Colors (Adaptive)

    static let formlogCard = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1.0)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    static let formlogCardSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.173, blue: 0.184, alpha: 1.0)
            : UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1.0)
    })

    // MARK: - Fill Colors (Adaptive)

    static let formlogFillPrimary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2)
            : UIColor(red: 0.471, green: 0.471, blue: 0.502, alpha: 0.2)
    })

    static let formlogFillSecondary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.16)
            : UIColor(red: 0.471, green: 0.471, blue: 0.502, alpha: 0.16)
    })

    static let formlogFillTertiary = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12)
            : UIColor(red: 0.463, green: 0.463, blue: 0.502, alpha: 0.12)
    })

    // MARK: - Separator (Adaptive)

    static let formlogSeparator = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.847, green: 0.847, blue: 0.863, alpha: 0.12)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.12)
    })

    static let formlogSeparatorOpaque = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.275, green: 0.275, blue: 0.286, alpha: 1.0)
            : UIColor(red: 0.776, green: 0.776, blue: 0.784, alpha: 1.0)
    })

    // MARK: - Chart Colors

    static let chart1 = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let chart2 = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let chart3 = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let chart4 = Color(red: 1.0, green: 0.176, blue: 0.333)
    static let chart5 = Color(red: 0.686, green: 0.322, blue: 0.871)

    /// Chart gradient fill — primary green fading to transparent
    static let chartFillStart = Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.25)
    static let chartFillEnd = Color(red: 0.188, green: 0.820, blue: 0.345).opacity(0.02)
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

// MARK: - Typography (SF Pro Dynamic Type Scale)

extension Font {
    /// Caption2 — 11pt Regular
    static let blCaption2 = Font.system(size: 11, weight: .regular, design: .default)
    /// Caption1 — 12pt Regular
    static let blCaption1 = Font.system(size: 12, weight: .regular)
    /// Footnote — 13pt Regular
    static let blFootnote = Font.system(size: 13, weight: .regular)
    /// Footnote Medium — 13pt Medium
    static let blFootnoteMedium = Font.system(size: 13, weight: .medium)
    /// Subhead — 14pt Regular
    static let blSubhead = Font.system(size: 14, weight: .regular)
    /// Subhead Semibold — 14pt Semibold
    static let blSubheadSemibold = Font.system(size: 14, weight: .semibold)
    /// Body — 15pt Regular
    static let blBody = Font.system(size: 15, weight: .regular)
    /// Body Medium — 15pt Medium
    static let blBodyMedium = Font.system(size: 15, weight: .medium)
    /// Body Semibold — 15pt Semibold
    static let blBodySemibold = Font.system(size: 15, weight: .semibold)
    /// Title3 — 16pt Regular
    static let blTitle3 = Font.system(size: 16, weight: .regular)
    /// Title3 Semibold — 16pt Semibold
    static let blTitle3Semibold = Font.system(size: 16, weight: .semibold)
    /// Title2 — 18pt Semibold Rounded
    static let blTitle2 = Font.system(size: 18, weight: .semibold, design: .rounded)
    /// Title1 — 22pt Semibold Rounded
    static let blTitle1 = Font.system(size: 22, weight: .semibold, design: .rounded)
    /// Large Title — 26pt Bold Rounded
    static let blLargeTitle = Font.system(size: 26, weight: .bold, design: .rounded)

    // MARK: Display (Hero Numbers for Metric Cards)

    /// Display1 — 32pt Bold Rounded
    static let blDisplay1 = Font.system(size: 32, weight: .bold, design: .rounded)
    /// Display2 — 40pt Bold Rounded
    static let blDisplay2 = Font.system(size: 40, weight: .bold, design: .rounded)
    /// Display3 — 50pt Bold Rounded
    static let blDisplay3 = Font.system(size: 50, weight: .bold, design: .rounded)

    // MARK: Monospaced Numbers

    /// Mono Caption — 11pt Regular Monospaced
    static let blMonoCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
    /// Mono Footnote — 13pt Regular Monospaced
    static let blMonoFootnote = Font.system(size: 13, weight: .regular, design: .monospaced)
    /// Mono Body — 15pt Regular Monospaced
    static let blMonoBody = Font.system(size: 15, weight: .regular, design: .monospaced)
    /// Mono Title — 18pt Semibold Monospaced
    static let blMonoTitle = Font.system(size: 18, weight: .semibold, design: .monospaced)
    /// Mono Display — 32pt Bold Monospaced
    static let blMonoDisplay = Font.system(size: 32, weight: .bold, design: .monospaced)
}

// MARK: - Corner Radius

extension CGFloat {
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 14
    static let radiusXl: CGFloat = 16
    static let radius2Xl: CGFloat = 20
    /// 24pt — large card / modal corner
    static let radius3Xl: CGFloat = 24
    static let radiusFull: CGFloat = 9999
}

// MARK: - Spacing

extension CGFloat {
    static let spacingXs: CGFloat = 4
    static let spacingSm: CGFloat = 8
    static let spacingMd: CGFloat = 12
    static let spacingLg: CGFloat = 16
    static let spacingXl: CGFloat = 20
    static let spacing2Xl: CGFloat = 24
    static let spacing3Xl: CGFloat = 32
    static let spacing4Xl: CGFloat = 40
    /// 48pt — section-level vertical spacing
    static let spacing5Xl: CGFloat = 48
}

// MARK: - Gradients

extension LinearGradient {
    /// Brand gradient — primary green to accent blue
    static let formlogGradient = LinearGradient(
        colors: [.formlogPrimary, .formlogAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Chart fill gradient — primary green fading to transparent
    static let chartGradient = LinearGradient(
        colors: [.chartFillStart, .chartFillEnd],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Modifiers

extension View {

    /// Standard BodyLog card — white/dark surface, rounded corners, subtle separator border
    func blCard() -> some View {
        self
            .background(Color.formlogCard)
            .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
            .overlay(
                RoundedRectangle(cornerRadius: .radiusXl)
                    .stroke(Color.formlogSeparator, lineWidth: 0.5)
            )
    }

    /// iOS Settings-style section header label
    func blSectionHeader(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: .spacingXs) {
            Text(text.uppercased())
                .font(.blCaption1)
                .foregroundColor(Color.formlogTextSecondary)
                .padding(.horizontal, .spacingLg)
            self
        }
    }

    /// Circular metric icon with colored background
    func blMetricIcon(_ name: String, color: Color, size: CGFloat = 28) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
            Image(systemName: name)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    /// 32pt bold title with letter spacing for hero sections
    func blLargeTitle(_ text: String) -> some View {
        Text(text)
            .font(.blDisplay1)
            .tracking(-0.5)
            .foregroundColor(Color.formlogTextPrimary)
    }

    /// Standard iOS navigation bar appearance
    func blNavigationBar() -> some View {
        self
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.formlogBgGrouped, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)
    }
}

// MARK: - Haptic Feedback

enum BodyLogHaptics {
    /// Light tap feedback
    @MainActor static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    /// Medium tap feedback
    @MainActor static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    /// Heavy tap feedback
    @MainActor static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    /// Success notification feedback
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    /// Warning notification feedback
    @MainActor static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
