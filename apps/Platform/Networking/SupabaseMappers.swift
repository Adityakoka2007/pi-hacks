import Foundation

struct HealthSummaryRow: Codable {
    let summaryDate: String
    let sleepHours: Double
    let steps: Int
    let restingHeartRate: Double?
    let heartRateVariability: Double?
}

struct ScheduleSummaryRow: Codable {
    let summaryDate: String
    let eventCount: Int
    let busyHours: Double
    let backToBackCount: Int
    let lateNightEvents: Int
}

struct CheckInRow: Codable {
    let checkInDate: String
    let stressLevel: Int
    let energyLevel: Int
    let caffeineServings: Int
    let notes: String?
}

// MARK: - analyze-stress edge function

/// A single calendar event passed from EventKit to enrich GPT recommendations.
struct CalendarEventPayload: Encodable {
    let title: String
    let startTime: String  // "HH:MM"
    let endTime: String    // "HH:MM"
    let isBackToBack: Bool?

    enum CodingKeys: String, CodingKey {
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case isBackToBack = "is_back_to_back"
    }
}

struct AnalyzeStressRequest: Encodable {
    let targetDate: String           // "YYYY-MM-DD"
    let calendarEvents: [CalendarEventPayload]?

    enum CodingKeys: String, CodingKey {
        case targetDate = "target_date"
        case calendarEvents = "calendar_events"
    }
}

struct AnalyzeStressResponse: Decodable {
    /// Raw 0–10 score stored in the DB; divide by 10 to get 0–1 for StressPrediction.
    let stressScore: Double
    let riskLevel: String
    let topFactors: [String]
    let recommendations: [RecommendationRow]

    enum CodingKeys: String, CodingKey {
        case stressScore = "stress_score"
        case riskLevel = "risk_level"
        case topFactors = "top_factors"
        case recommendations
    }
}

struct RecommendationRow: Decodable {
    let id: UUID
    let title: String
    let body: String
    let rationale: String
    let category: String
}
