// AchievementView.swift
// 成就/里程碑展示视图

import SwiftUI

struct AchievementView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary header
                    achievementSummary
                        .padding(.horizontal, 20)

                    // Achievement grid by category
                    ForEach(AchievementType.Category.allCases, id: \.rawValue) { category in
                        categorySection(category)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle(L10n.string("成就"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完成")) { dismiss() }
                        .foregroundColor(.formlogPrimary)
                }
            }
        }
    }

    // MARK: - Summary Header

    private var achievementSummary: some View {
        VStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.systemGray5, lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(Color.formlogPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progressFraction)

                VStack(spacing: 2) {
                    Text("\(appState.achievements.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.formlogPrimary)
                    Text("/ \(AchievementType.allCases.count)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Text(L10n.string("已解锁成就"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(Color.systemBackground)
        .cornerRadius(16)
    }

    private var progressFraction: CGFloat {
        guard !AchievementType.allCases.isEmpty else { return 0 }
        return CGFloat(appState.achievements.count) / CGFloat(AchievementType.allCases.count)
    }

    // MARK: - Category Section

    private func categorySection(_ category: AchievementType.Category) -> some View {
        let achievementsInCategory = AchievementType.allCases.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: 12) {
            Text(category.localizedName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(achievementsInCategory) { type in
                    achievementCard(type)
                }
            }
        }
    }

    private func achievementCard(_ type: AchievementType) -> some View {
        let isUnlocked = appState.isAchievementUnlocked(type)
        let progress = AchievementManager.shared.progress(for: type, entryStore: entryStore, goalStore: goalStore)

        return VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.formlogPrimary.opacity(0.1) : Color.systemGray6)
                    .frame(width: 48, height: 48)

                Image(systemName: type.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isUnlocked ? .formlogPrimary : .systemGray3)
            }

            // Name
            Text(type.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .lineLimit(1)

            // Status or progress
            if isUnlocked {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(L10n.string("已解锁"))
                        .font(.system(size: 11))
                }
                .foregroundColor(.formlogPrimary)
            } else if let prog = progress {
                // Progress bar
                                    let progressFraction = prog.target > 0 ? CGFloat(prog.current) / CGFloat(prog.target) : 0

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.systemGray5)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.formlogPrimary.opacity(0.6))
                            .frame(width: geo.size.width * min(max(progressFraction, 0), 1), height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(prog.current)/\(prog.target)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Text(L10n.string("未开始"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.systemBackground)
        .cornerRadius(12)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}

// MARK: - Achievement Notification Banner

struct AchievementNotificationBanner: View {
    let achievement: Achievement
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Icon with animation
                    ZStack {
                        Circle()
                            .fill(Color.formlogPrimary.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: achievement.type.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.formlogPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("🎉 成就解锁！"))
                            .font(.system(size: 14, weight: .bold))
                        Text(achievement.type.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(achievement.type.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.systemGray3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemBackground)
            }
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    AchievementView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
}
