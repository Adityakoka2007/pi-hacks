import Foundation

struct StressPrediction: Codable {
    enum RiskLevel: String, Codable {
        case low
        case medium
        case high
    }

    let riskLevel: RiskLevel
    let score: Double
    let topFactors: [String]
}

extension StressPrediction {
    static let sample = StressPrediction(
        riskLevel: .medium,
        score: 0.61,
        topFactors: [
            "Sleep has been below baseline for 2 nights",
            "Tomorrow has multiple back-to-back calendar blocks"
        ]
    )
}
