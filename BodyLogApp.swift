// BodyLogApp.swift
// @main 入口

import SwiftUI

@main
struct BodyLogApp: App {
    @State private var appState = AppState.shared
    @State private var entryStore = BodyEntryStore()
    @State private var goalStore = GoalStore()
    @State private var purchaseManager = PurchaseManager.shared

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
