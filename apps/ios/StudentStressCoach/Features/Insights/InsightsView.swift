import SwiftUI

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Patterns") {
                    Text("You tend to feel more stressed after 2 nights of shorter sleep.")
                    Text("Busy afternoons correlate with higher evening stress.")
                }

                Section("Next") {
                    Text("Add charts and trend summaries once daily history is stored.")
                }
            }
            .navigationTitle("Insights")
        }
    }
}

#Preview {
    InsightsView()
}
