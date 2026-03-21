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
