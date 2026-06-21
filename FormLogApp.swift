// FormLogApp.swift
// @main 入口

import SwiftUI

@main
struct FormLogApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var entryStore = BodyEntryStore()
    @StateObject private var goalStore = GoalStore()
    @StateObject private var purchaseManager = PurchaseManager.shared

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
