// FormLogApp.swift
// @main 入口

import SwiftUI

@main
struct FormLogApp: App {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var entryStore = BodyEntryStore()
    @StateObject private var goalStore = GoalStore()
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(entryStore)
                .environmentObject(goalStore)
                .environmentObject(purchaseManager)
                .preferredColorScheme(colorScheme)
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
