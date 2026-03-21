import SwiftUI

struct DashboardView: View {
    private let prediction = StressPrediction.sample

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StressScoreCard(prediction: prediction)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Factors")
                            .font(.headline)

                        ForEach(prediction.topFactors, id: \.self) { factor in
                            Label(factor, systemImage: "exclamationmark.circle")
                        }
                    }

                    RecommendationListView(recommendations: Recommendation.sampleData)
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }
}

#Preview {
    DashboardView()
}
