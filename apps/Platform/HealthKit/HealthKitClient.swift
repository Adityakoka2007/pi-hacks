import Foundation

final class HealthKitClient {
    func requestAuthorization() async throws {
        // Implement HealthKit permissions in Xcode once the app target is created.
    }

    func fetchLatestSummary() async throws -> DailyHealthSummary {
        DailyHealthSummary(
            id: UUID(),
            date: .now,
            sleepHours: 6.8,
            steps: 7120,
            restingHeartRate: 65,
            heartRateVariability: 42
        )
    }
}
