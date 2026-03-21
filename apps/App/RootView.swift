import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }

            CheckInView()
                .tabItem {
                    Label("Check-In", systemImage: "heart.text.square")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    RootView()
}
