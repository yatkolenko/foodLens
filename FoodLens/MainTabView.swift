import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Обзор", systemImage: "calendar") }

            ProgressStatsView()
                .tabItem { Label("Прогресс", systemImage: "chart.xyaxis.line") }

            NutritionCalculatorView()
                .tabItem { Label("Калькулятор", systemImage: "function") }

            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
        }
        .tint(DesignTokens.accentGreen)
        .toolbarBackground(DesignTokens.cardElevated, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct RootContainerView: View {
    @EnvironmentObject private var store: FoodStore

    var body: some View {
        Group {
            if store.onboardingCompleted, store.profile != nil {
                MainTabView()
            } else {
                NavigationStack {
                    OnboardingFlowView()
                }
            }
        }
    }
}
