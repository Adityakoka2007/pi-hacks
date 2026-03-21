import Foundation

struct DailyHealthSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let sleepHours: Double
    let steps: Int
    let restingHeartRate: Double?
    let heartRateVariability: Double?
}
