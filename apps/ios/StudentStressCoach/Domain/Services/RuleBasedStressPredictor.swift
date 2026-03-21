import Foundation

struct RuleBasedStressPredictor: StressPredicting {
    func predict(from features: StressFeatures) async throws -> StressPrediction {
        var score = 0.0
        var factors: [String] = []

        if features.sleepDebtHours > 1.5 {
            score += 0.25
            factors.append("Sleep has fallen below your recent baseline")
        }

        if features.scheduleIntensityScore > 0.7 {
            score += 0.25
            factors.append("Tomorrow's calendar is unusually dense")
        }

        if features.activityTrendScore < 0.4 {
            score += 0.15
            factors.append("Your recent activity is lower than usual")
        }

        if features.recentStressAverage >= 4 {
            score += 0.25
            factors.append("Recent check-ins show sustained stress")
        }

        let clampedScore = min(max(score, 0.05), 0.95)
        let level: StressPrediction.RiskLevel

        switch clampedScore {
        case ..<0.33:
            level = .low
        case ..<0.66:
            level = .medium
        default:
            level = .high
        }

        return StressPrediction(
            riskLevel: level,
            score: clampedScore,
            topFactors: factors.isEmpty ? ["No strong risk factors detected today"] : factors
        )
    }
}
