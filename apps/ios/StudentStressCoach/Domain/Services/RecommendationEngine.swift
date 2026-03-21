import Foundation

struct RecommendationEngine: RecommendationProviding {
    func recommendations(for prediction: StressPrediction, features: StressFeatures) -> [Recommendation] {
        var items: [Recommendation] = []

        if features.sleepDebtHours > 1 {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Protect your bedtime",
                    body: "Keep your final 30 minutes before bed clear of heavy work.",
                    rationale: "Reducing sleep drift can lower next-day stress risk.",
                    category: "sleep"
                )
            )
        }

        if features.scheduleIntensityScore > 0.6 {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Add a buffer block",
                    body: "Create one 10-minute gap between your busiest commitments tomorrow.",
                    rationale: "Breaks reduce stress spikes during dense calendar days.",
                    category: "schedule"
                )
            )
        }

        if items.isEmpty {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Keep your current routine",
                    body: "Your current patterns look stable. Maintain sleep and movement today.",
                    rationale: "No major risk factors are elevated right now.",
                    category: "general"
                )
            )
        }

        return items
    }
}
