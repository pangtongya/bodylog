// FormLogWidget.swift
// Widget Extension - Display weight, streak, and quick record entry

import WidgetKit
import SwiftUI

// MARK: - Inline Design Tokens (Widget target has no access to ColorExtensions.swift)

private enum WidgetColors {
    /// Primary green -- Apple Green #30D158
    static let primary = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    /// Primary at 0.15 opacity -- highlighted surfaces
    static let primarySoft = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255).opacity(0.15)
    /// Streak orange
    static let orange = Color.orange
    /// Orange at 0.15 opacity -- streak badge background
    static let orangeSoft = Color.orange.opacity(0.15)
}

// MARK: - iOS 17 Availability Helper

extension View {
    @ViewBuilder
    func ifAvailable_containerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color(red: 242/255, green: 242/255, blue: 247/255)
            }
        } else {
            self
        }
    }
}

private enum WidgetMetrics {
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 16
    static let spacingXs: CGFloat = 4
    static let spacingSm: CGFloat = 8
    static let spacingMd: CGFloat = 12
    static let spacingLg: CGFloat = 16
}

// MARK: - Widget-scoped L10n (avoids conflict with main app's L10n enum)

private enum WidgetL10n {
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

// MARK: - Widget Bundle

@main
struct FormLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        FormLogWidget()
    }
}

// MARK: - Timeline Entry

struct FormLogEntry: TimelineEntry {
    let date: Date
    let weight: Double?
    let weightUnit: String
    let streak: Int
    let lastRecordDate: Date?
    let goal: Double?
    let goalProgress: Double?
}

// MARK: - Provider

struct FormLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> FormLogEntry {
        FormLogEntry(
            date: Date(),
            weight: 70.5,
            weightUnit: "kg",
            streak: 7,
            lastRecordDate: Date(),
            goal: 65.0,
            goalProgress: 0.7
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FormLogEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FormLogEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> FormLogEntry {
        let defaults = UserDefaults(suiteName: "group.com.pangtong.formlog") ?? .standard

        let weight = defaults.double(forKey: "latestWeight")
        let weightUnit = defaults.string(forKey: "weightUnit") ?? "kg"
        let streak = defaults.integer(forKey: "currentStreak")
        let lastRecordTimestamp = defaults.double(forKey: "lastRecordDate")
        let lastRecordDate = lastRecordTimestamp > 0 ? Date(timeIntervalSince1970: lastRecordTimestamp) : nil
        let goal = defaults.double(forKey: "currentGoal")
        let goalProgress = defaults.double(forKey: "goalProgress")

        return FormLogEntry(
            date: Date(),
            weight: weight > 0 ? weight : nil,
            weightUnit: weightUnit,
            streak: streak,
            lastRecordDate: lastRecordDate,
            goal: goal > 0 ? goal : nil,
            goalProgress: goalProgress > 0 ? goalProgress : nil
        )
    }
}

// MARK: - Widget

struct FormLogWidget: Widget {
    let kind: String = "FormLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FormLogProvider()) { entry in
            FormLogWidgetEntryView(entry: entry)
                .ifAvailable_containerBackground()
        }
        .configurationDisplayName("FormLog")
        .description(WidgetL10n.localized("快速查看体重和记录入口"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Entry View Router

struct FormLogWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FormLogEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: FormLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.spacingSm) {
            // Header
            HStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 14))
                    .foregroundColor(WidgetColors.primary)
                Text("FormLog")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            // Weight + Streak badge inline
            if let weight = entry.weight {
                HStack(alignment: .firstTextBaseline, spacing: WidgetMetrics.spacingSm) {
                    Text(String(format: "%.1f", weight))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                    Text(entry.weightUnit)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    if entry.streak > 0 {
                        streakBadge(count: entry.streak)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: WidgetMetrics.spacingXs) {
                    Text("--")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Text(WidgetL10n.localized("暂无数据"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(WidgetMetrics.spacingMd)
        .background(
            RoundedRectangle(cornerRadius: WidgetMetrics.radiusLg)
                .fill(.ultraThinMaterial)
        )
        .widgetURL(URL(string: "formlog://record"))
    }

    private func streakBadge(count: Int) -> some View {
        HStack(spacing: WidgetMetrics.spacingXs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
        .foregroundColor(WidgetColors.orange)
        .padding(.horizontal, WidgetMetrics.spacingSm)
        .padding(.vertical, WidgetMetrics.spacingXs)
        .background(
            Capsule().fill(WidgetColors.orangeSoft)
        )
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: FormLogEntry

    var body: some View {
        HStack(spacing: WidgetMetrics.spacingLg) {
            // Left: Weight
            VStack(alignment: .leading, spacing: WidgetMetrics.spacingXs) {
                HStack {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 14))
                        .foregroundColor(WidgetColors.primary)
                    Text("FormLog")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                if let weight = entry.weight {
                    HStack(alignment: .lastTextBaseline, spacing: WidgetMetrics.spacingXs) {
                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                        Text(entry.weightUnit)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                if let lastDate = entry.lastRecordDate {
                    HStack(spacing: WidgetMetrics.spacingXs) {
                        Text(WidgetL10n.localized("上次记录:"))
                        Text(formatDate(lastDate))
                            .monospacedDigit()
                        Text(relativeTimeString(from: lastDate))
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: Stats & Quick Action
            VStack(alignment: .center, spacing: WidgetMetrics.spacingSm) {
                // Streak
                if entry.streak > 0 {
                    HStack(spacing: WidgetMetrics.spacingXs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(WidgetColors.orange)
                        Text("\(entry.streak)" + WidgetL10n.localized("天连续"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetColors.orange)
                            .monospacedDigit()
                    }
                }

                // Goal Progress Ring
                if let _ = entry.goal, let progress = entry.goalProgress {
                    goalProgressRing(progress: progress)
                }

                Spacer(minLength: 0)

                // Quick Action Button
                Link(destination: URL(string: "formlog://record") ?? URL(string: "https://pangtongya.github.io/bodylog/support.html")!) {
                    HStack(spacing: WidgetMetrics.spacingXs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text(WidgetL10n.localized("记录"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WidgetMetrics.spacingSm)
                    .background(
                        RoundedRectangle(cornerRadius: WidgetMetrics.radiusSm)
                            .fill(WidgetColors.primary)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WidgetMetrics.spacingMd)
        .background(
            RoundedRectangle(cornerRadius: WidgetMetrics.radiusLg)
                .fill(.ultraThinMaterial)
        )
        .widgetURL(URL(string: "formlog://record"))
    }

    // MARK: - Goal Progress Ring

    private func goalProgressRing(progress: Double) -> some View {
        let clampedProgress = min(max(progress, 0), 1.0)
        let percentage = Int(clampedProgress * 100)

        return ZStack {
            // Background track
            Circle()
                .stroke(WidgetColors.primarySoft, lineWidth: 5)

            // Foreground arc
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    WidgetColors.primary,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(percentage)%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
        }
        .frame(width: 60, height: 60)
    }

    // MARK: - Date Formatting

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMdd")
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func relativeTimeString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "(" + WidgetL10n.localized("今天") + ")"
        } else if calendar.isDateInYesterday(date) {
            return "(" + WidgetL10n.localized("昨天") + ")"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days > 0 && days < 30 {
                return "(\(days)" + WidgetL10n.localized("天前") + ")"
            }
            return ""
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    FormLogWidget()
} timeline: {
    FormLogEntry(
        date: Date(),
        weight: 70.5,
        weightUnit: "kg",
        streak: 7,
        lastRecordDate: Date(),
        goal: 65.0,
        goalProgress: 0.7
    )
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    FormLogWidget()
} timeline: {
    FormLogEntry(
        date: Date(),
        weight: 70.5,
        weightUnit: "kg",
        streak: 7,
        lastRecordDate: Date(),
        goal: 65.0,
        goalProgress: 0.7
    )
}
