import Foundation

struct DailyScheduleSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let eventCount: Int
    let busyHours: Double
    let backToBackCount: Int
    let lateNightEvents: Int
}
