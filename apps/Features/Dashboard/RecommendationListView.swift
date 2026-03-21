import SwiftUI

struct RecommendationListView: View {
    let recommendations: [Recommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Actions")
                .font(.headline)

            ForEach(recommendations) { recommendation in
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(.subheadline.weight(.semibold))
                    Text(recommendation.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
