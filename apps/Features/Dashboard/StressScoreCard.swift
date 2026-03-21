import SwiftUI

struct StressScoreCard: View {
    let prediction: StressPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stress Risk")
                .font(.headline)

            Text(prediction.riskLevel.rawValue.capitalized)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Score: \(prediction.score.formatted(.percent.precision(.fractionLength(0))))")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }
}
