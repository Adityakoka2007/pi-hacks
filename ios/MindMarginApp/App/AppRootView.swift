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
    @State private var currentTab: MindMarginAppModel.AppTab = .dashboard
    @GestureState private var dragOffset: CGFloat = 0

    private let tabs = MindMarginAppModel.AppTab.allCases

    var body: some View {
        NavigationStack(path: $appModel.navigationPath) {
            ZStack {
                MindMarginTheme.background
                    .ignoresSafeArea()

                currentScreenPager
            }
            .safeAreaInset(edge: .bottom) {
                AppTabBar(selectedTab: $currentTab)
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
            .onAppear {
                currentTab = appModel.selectedTab
            }
            .onChange(of: currentTab) { _, newValue in
                if appModel.selectedTab != newValue {
                    appModel.selectedTab = newValue
                }
            }
            .onChange(of: appModel.selectedTab) { _, newValue in
                if currentTab != newValue {
                    currentTab = newValue
                }
            }
        }
    }

    private var currentScreenPager: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                DashboardScreen()
                    .frame(width: geometry.size.width)

                CheckInScreen()
                    .frame(width: geometry.size.width)

                InsightsScreen()
                    .frame(width: geometry.size.width)

                SettingsScreen()
                    .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width * CGFloat(tabs.count), alignment: .leading)
            .offset(x: -CGFloat(selectedTabIndex) * geometry.size.width + dragOffset)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: currentTab)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .updating($dragOffset) { value, state, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }

                        let isAtLeadingEdge = selectedTabIndex == 0 && value.translation.width > 0
                        let isAtTrailingEdge = selectedTabIndex == tabs.count - 1 && value.translation.width < 0
                        let resistance: CGFloat = (isAtLeadingEdge || isAtTrailingEdge) ? 0.22 : 1.0
                        state = value.translation.width * resistance
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }

                        let width = geometry.size.width
                        let threshold = width * 0.58
                        let predictedTravel = value.predictedEndTranslation.width
                        let resolvedTravel = abs(predictedTravel) > abs(value.translation.width)
                            ? predictedTravel
                            : value.translation.width

                        var nextIndex = selectedTabIndex
                        if resolvedTravel <= -threshold {
                            nextIndex += 1
                        } else if resolvedTravel >= threshold {
                            nextIndex -= 1
                        }

                        nextIndex = min(max(nextIndex, 0), tabs.count - 1)
                        currentTab = tabs[nextIndex]
                    }
            )
        }
    }

    private var selectedTabIndex: Int {
        tabs.firstIndex(of: currentTab) ?? 0
    }
}

private struct AppTabBar: View {
    @Binding var selectedTab: MindMarginAppModel.AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MindMarginAppModel.AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))

                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? MindMarginTheme.indigo : MindMarginTheme.textTertiary)
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
