import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        Group {
            if appModel.isOnboardingComplete {
                MainAppView()
            } else {
                OnboardingFlowView()
            }
        }
        .background(MindMarginTheme.background.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: appModel.onboardingStep)
    }
}

private struct MainAppView: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        NavigationStack(path: $appModel.navigationPath) {
            ZStack {
                MindMarginTheme.background
                    .ignoresSafeArea()

                currentScreen
            }
            .safeAreaInset(edge: .bottom) {
                AppTabBar()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .background(MindMarginTheme.background.opacity(0.94))
            }
            .navigationDestination(for: MindMarginAppModel.Route.self) { route in
                switch route {
                case .actionPlan:
                    ActionPlanScreen()
                }
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch appModel.selectedTab {
        case .dashboard:
            DashboardScreen()
        case .checkIn:
            CheckInScreen()
        case .insights:
            InsightsScreen()
        case .settings:
            SettingsScreen()
        }
    }
}

private struct AppTabBar: View {
    @EnvironmentObject private var appModel: MindMarginAppModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MindMarginAppModel.AppTab.allCases) { tab in
                Button {
                    appModel.selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 18, weight: appModel.selectedTab == tab ? .semibold : .regular))

                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(appModel.selectedTab == tab ? MindMarginTheme.indigo : MindMarginTheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(MindMarginTheme.border, lineWidth: 1)
        }
    }
}
