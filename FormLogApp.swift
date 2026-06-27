// FormLogApp.swift
// @main 入口

import SwiftUI

@main
struct FormLogApp: App {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var entryStore = BodyEntryStore()
    @StateObject private var goalStore = GoalStore()
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    init() {
        // Configure global UI appearance for Apple HIG compliance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Table view appearance
        UITableView.appearance().backgroundColor = UIColor.clear
        let selectionBgView = UIView()
        selectionBgView.backgroundColor = UIColor(Color.formlogPrimary).withAlphaComponent(0.1)
        UITableViewCell.appearance().selectedBackgroundView = selectionBgView
    }

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
        Group {
            if appState.hasCompletedOnboarding {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            } else {
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}
