import SwiftUI
import UIKit

@main
struct FormLogApp: App {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var entryStore = BodyEntryStore()
    @StateObject private var goalStore = GoalStore()
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var autoBackupManager = AutoBackupManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
                .environmentObject(purchaseManager)
                .environmentObject(autoBackupManager)
                .preferredColorScheme(colorScheme)
                .onAppear {
                    purchaseManager.start()
                    setupQuickActions()
                    if appState.isPro {
                        autoBackupManager.checkAndPerformAutoBackup()
                    }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appState.theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func setupQuickActions() {
        let newEntryAction = UIApplicationShortcutItem(
            type: "com.pangtong.formlog.newEntry",
            localizedTitle: L10n.string("快速记录"),
            localizedSubtitle: L10n.string("添加今天的身体数据"),
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
            userInfo: nil
        )

        let trendAction = UIApplicationShortcutItem(
            type: "com.pangtong.formlog.viewTrend",
            localizedTitle: L10n.string("查看趋势"),
            localizedSubtitle: L10n.string("查看数据变化趋势"),
            icon: UIApplicationShortcutIcon(systemImageName: "chart.line.uptrend.xyaxis"),
            userInfo: nil
        )

        let goalsAction = UIApplicationShortcutItem(
            type: "com.pangtong.formlog.viewGoals",
            localizedTitle: L10n.string("我的目标"),
            localizedSubtitle: L10n.string("查看目标进度"),
            icon: UIApplicationShortcutIcon(systemImageName: "target"),
            userInfo: nil
        )

        UIApplication.shared.shortcutItems = [newEntryAction, trendAction, goalsAction]
    }
}

final class QuickActionManager {
    static let shared = QuickActionManager()

    func handleShortcutItem(_ item: UIApplicationShortcutItem) {
        switch item.type {
        case "com.pangtong.formlog.newEntry":
            NotificationCenter.default.post(name: .quickActionNewEntry, object: nil)
        case "com.pangtong.formlog.viewTrend":
            NotificationCenter.default.post(name: .switchToTrendTab, object: nil)
        case "com.pangtong.formlog.viewGoals":
            NotificationCenter.default.post(name: .switchToGoalsTab, object: nil)
        default:
            break
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
    }
}
