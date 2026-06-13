// BodyLogApp.swift
// @main 入口

import SwiftUI

@main
struct BodyLogApp: App {
    @StateObject private var appState: AppState
    @StateObject private var entryStore: BodyEntryStore
    @StateObject private var goalStore: GoalStore
    @StateObject private var purchaseManager: PurchaseManager

    init() {
        _appState = StateObject(wrappedValue: AppState.shared)
        _entryStore = StateObject(wrappedValue: BodyEntryStore())
        _goalStore = StateObject(wrappedValue: GoalStore())
        _purchaseManager = StateObject(wrappedValue: PurchaseManager.shared)
    }

    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appState)
                    .environmentObject(entryStore)
                    .environmentObject(goalStore)
                    .environmentObject(purchaseManager)
                    .preferredColorScheme(colorScheme)
            } else {
                OnboardingView()
                    .environmentObject(appState)
                    .environmentObject(entryStore)
                    .environmentObject(goalStore)
                    .environmentObject(purchaseManager)
                    .preferredColorScheme(colorScheme)
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
}
