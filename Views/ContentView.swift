// ContentView.swift
// Root Tab Navigation — Premium Apple HIG Style

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var selectedTab: Tab = .home
    @State private var showLogSheet: Bool = false

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable {
        case home, trend, goals, settings

        var title: String {
            switch self {
            case .home: return L10n.string("首页")
            case .trend: return L10n.string("趋势")
            case .goals: return L10n.string("目标")
            case .settings: return L10n.string("设置")
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .trend: return "chart.line.uptrend.xyaxis"
            case .goals: return "target"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
            trendTab
            goalsTab
            settingsTab
        }
        .tint(.formlogPrimary)
        .toolbarBackground(Color.formlogCard, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            configureTabBarAppearance()
            if purchaseManager.proProduct == nil {
                Task { await purchaseManager.loadProducts() }
            }
            checkAchievements()
        }
        .sheet(isPresented: $showLogSheet) {
            LogEntryView(isPresented: $showLogSheet)
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToHomeTab)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .home
            }
        }
        .onOpenURL { url in
            if url.absoluteString.contains("formlog://record") && appState.hasCompletedOnboarding {
                showLogSheet = true
                BodyLogHaptics.medium()
            }
        }
    }

    // MARK: - Tab Views

    private var homeTab: some View {
        NavigationStack {
            HomeView(showLogSheet: $showLogSheet)
        }
        .tabItem {
            Label(Tab.home.title, systemImage: Tab.home.icon)
        }
        .tag(Tab.home)
    }

    private var trendTab: some View {
        NavigationStack {
            TrendView()
        }
        .tabItem {
            Label(Tab.trend.title, systemImage: Tab.trend.icon)
        }
        .tag(Tab.trend)
    }

    private var goalsTab: some View {
        NavigationStack {
            GoalsView()
        }
        .tabItem {
            Label(Tab.goals.title, systemImage: Tab.goals.icon)
        }
        .tag(Tab.goals)
    }

    private var settingsTab: some View {
        NavigationStack {
            SettingsView()
        }
        .tabItem {
            Label(Tab.settings.title, systemImage: Tab.settings.icon)
        }
        .tag(Tab.settings)
    }

    // MARK: - Tab Bar Appearance

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Blur background matching the design system card color
        appearance.backgroundColor = UIColor(Color.formlogCard).withAlphaComponent(0.92)

        // Subtle top separator
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.25)
        appearance.shadowImage = nil

        // Active tab item color
        let activeColor = UIColor(Color.formlogPrimary)
        appearance.stackedLayoutAppearance.selected.iconColor = activeColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: activeColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // Inactive tab item color
        let inactiveColor = UIColor(Color.formlogTextQuaternary)
        appearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        // Compact / inline edge layout (iPad)
        appearance.compactInlineLayoutAppearance.selected.iconColor = activeColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: activeColor
        ]
        appearance.compactInlineLayoutAppearance.normal.iconColor = inactiveColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactiveColor
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Achievement Check

    private func checkAchievements() {
        let newAchievements = AchievementManager.shared.checkAndUnlockAchievements(
            entryStore: entryStore,
            goalStore: goalStore,
            existingAchievements: appState.achievements
        )
        if !newAchievements.isEmpty {
            appState.unlockAchievements(newAchievements)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let switchToHomeTab = Notification.Name("SwitchToHomeTab")
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
        .environmentObject(PurchaseManager.shared)
}
