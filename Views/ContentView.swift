// ContentView.swift
// 根导航（Tab Bar）

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var entryStore: BodyEntryStore
    @EnvironmentObject var goalStore: GoalStore
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var selectedTab: Tab = .home
    @State private var showLogSheet: Bool = false

    enum Tab: String, CaseIterable {
        case home, trend, goals, settings

        var title: String {
            switch self {
            case .home: return L10n.string("记录")
            case .trend: return L10n.string("趋势")
            case .goals: return L10n.string("目标")
            case .settings: return L10n.string("设置")
            }
        }
        var icon: String {
            switch self {
            case .home: return "house"
            case .trend: return "chart.line.uptrend.xyaxis"
            case .goals: return "target"
            case .settings: return "gearshape"
            }
        }
        var filledIcon: String {
            switch self {
            case .home: return "house.fill"
            case .trend: return "chart.line.uptrend.xyaxis"
            case .goals: return "target"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
                HomeView(showLogSheet: $showLogSheet)
                    .tabItem {
                        Label(Tab.home.title, systemImage: selectedTab == .home ? Tab.home.filledIcon : Tab.home.icon)
                    }
                    .tag(Tab.home)

                TrendView()
                    .tabItem {
                        Label(Tab.trend.title, systemImage: selectedTab == .trend ? Tab.trend.filledIcon : Tab.trend.icon)
                    }
                    .tag(Tab.trend)

                GoalsView()
                    .tabItem {
                        Label(Tab.goals.title, systemImage: selectedTab == .goals ? Tab.goals.filledIcon : Tab.goals.icon)
                    }
                    .tag(Tab.goals)

                SettingsView()
                    .tabItem {
                        Label(Tab.settings.title, systemImage: selectedTab == .settings ? Tab.settings.filledIcon : Tab.settings.icon)
                    }
                    .tag(Tab.settings)
        }
        .tint(.bodylogPrimary)
        .sheet(isPresented: $showLogSheet) {
            LogEntryView(isPresented: $showLogSheet)
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(BodyEntryStore())
        .environmentObject(GoalStore())
        .environmentObject(PurchaseManager.shared)
}
