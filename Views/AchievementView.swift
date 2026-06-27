// AchievementView.swift
// 成就/里程碑展示视图 — Premium Apple HIG Style

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
                    // Ring progress summary
                    summaryCard
                        .padding(.horizontal, 16)

                    // Achievement categories
                    ForEach(AchievementType.Category.allCases, id: \.rawValue) { category in
                        categorySection(category)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color.formlogBgGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text(L10n.string("返回"))
                                .font(.system(size: 17))
                        }
                    }
                    .foregroundColor(.formlogPrimary)
                }

                ToolbarItem(placement: .principal) {
                    Text(L10n.string("成就"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.formlogTextPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("完成")) { dismiss() }
                        .foregroundColor(.formlogPrimary)
                        .font(.system(size: 17))
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            // SVG-style ring progress
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.formlogFillTertiary, lineWidth: 10)
                    .frame(width: 120, height: 120)

                // Progress ring with trim
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        Color.formlogPrimary,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progressFraction)

                // Center text
                VStack(spacing: 2) {
                    Text("\(appState.achievements.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.formlogPrimary)

                    Text("\(AchievementType.allCases.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.formlogTextSecondary)
                        .textCase(.uppercase)
                }
            }

            // Unlocked count label
            Text(L10n.string("\(appState.achievements.count)/\(AchievementType.allCases.count) 已解锁"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: .radiusXl))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusXl)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
    }

    private var progressFraction: CGFloat {
        let total = AchievementType.allCases.count
        guard total > 0 else { return 0 }
        return CGFloat(appState.achievements.count) / CGFloat(total)
    }

    // MARK: - Category Section

    private func categorySection(_ category: AchievementType.Category) -> some View {
        let achievementsInCategory = AchievementType.allCases.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: 12) {
            // Section label
            Text(category.localizedName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.formlogTextSecondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            // 2x2 grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(achievementsInCategory) { type in
                    achievementCard(type)
                }
            }
        }
    }

    // MARK: - Achievement Card

    private func achievementCard(_ type: AchievementType) -> some View {
        let isUnlocked = appState.isAchievementUnlocked(type)
        let progress = AchievementManager.shared.progress(for: type, entryStore: entryStore, goalStore: goalStore)
        let isInProgress = !isUnlocked && progress != nil && progress!.current > 0

        return VStack(spacing: 10) {
            // Icon circle — 48px
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.formlogPrimaryPale : Color.formlogFillTertiary)
                    .frame(width: 48, height: 48)

                Image(systemName: type.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isUnlocked ? .formlogPrimary : .formlogTextSecondary)
            }

            // Achievement name — 14pt medium
            Text(type.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isUnlocked ? .formlogTextPrimary : (isInProgress ? .formlogTextSecondary : .formlogTextSecondary))
                .lineLimit(1)

            // Status indicator
            if isUnlocked {
                // Unlocked state
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text(L10n.string("已解锁"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.green)
            } else if isInProgress, let prog = progress {
                // In-progress state — progress bar + fraction text
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: .radiusFull)
                            .fill(Color.formlogFillTertiary)
                            .frame(height: 4)

                        // Fill
                        let fraction = prog.target > 0 ? CGFloat(prog.current) / CGFloat(prog.target) : 0
                        RoundedRectangle(cornerRadius: .radiusFull)
                            .fill(Color.formlogPrimary)
                            .frame(width: geo.size.width * min(max(fraction, 0), 1), height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(prog.current)/\(prog.target)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.formlogTextSecondary)
            } else {
                // Locked state
                Text(L10n.string("未开始"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.formlogTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.formlogCard)
        .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: .radiusMd)
                .stroke(Color.formlogSeparator, lineWidth: 1)
        )
        .opacity(isUnlocked ? 1.0 : (isInProgress ? 0.85 : 0.6))
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
                            .fill(Color.formlogPrimaryPale)
                            .frame(width: 44, height: 44)

                        Image(systemName: achievement.type.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.formlogPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("🎉 成就解锁！"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.formlogPrimary)
                        Text(achievement.type.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.formlogTextPrimary)
                        Text(achievement.type.description)
                            .font(.system(size: 12))
                            .foregroundColor(.formlogTextSecondary)
                    }

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.formlogFillTertiary)
                    }
                    .accessibilityLabel(L10n.string("关闭"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.formlogCard)
            }
            .clipShape(RoundedRectangle(cornerRadius: .radiusMd))
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
