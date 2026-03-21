import Foundation

struct Recommendation: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let rationale: String
    let category: String
}

extension Recommendation {
    static let sampleData: [Recommendation] = [
        Recommendation(
            id: UUID(),
            title: "Protect your evening wind-down",
            body: "Reserve 30 minutes before bed with no major work tasks.",
            rationale: "Sleep debt is one of your top stress drivers today.",
            category: "sleep"
        ),
        Recommendation(
            id: UUID(),
            title: "Insert a reset walk",
            body: "Take a 10-minute walk between your two busiest classes.",
            rationale: "Movement helps offset stress when schedule intensity rises.",
            category: "movement"
        )
    ]
}
