import Foundation

final class CalendarClient {
    func requestAccess() async throws {
        // Implement EventKit permissions in Xcode once the app target is created.
    }

    func fetchTomorrowSummary() async throws -> DailyScheduleSummary {
        DailyScheduleSummary(
            id: UUID(),
            date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
            eventCount: 6,
            busyHours: 5.5,
            backToBackCount: 3,
            lateNightEvents: 1
        )
    }
}
