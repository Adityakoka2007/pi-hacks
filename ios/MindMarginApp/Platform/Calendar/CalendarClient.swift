import EventKit
import Foundation

final class CalendarClient {
    private let eventStore = EKEventStore()
    private let calendar = Calendar.current

    func authorizationState() -> PlatformAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted, .writeOnly:
            return .denied
        default:
            return .unavailable
        }
    }

    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted else {
                throw PlatformDataError.calendarAuthorizationMissing
            }
        } else {
            let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: granted)
                }
            }
            guard granted else {
                throw PlatformDataError.calendarAuthorizationMissing
            }
        }
    }

    func fetchTomorrowSummary() async throws -> DailyScheduleSummary {
        guard authorizationState() == .authorized else {
            throw PlatformDataError.calendarAuthorizationMissing
        }

        let events = try await fetchEventsForTomorrow()
        let tomorrow = tomorrowStartDate

        let busyHours = events.reduce(0.0) { partialResult, event in
            partialResult + event.endDate.timeIntervalSince(event.startDate) / 3_600
        }
        let backToBackCount = countBackToBackTransitions(in: events)
        let lateNightEvents = events.filter { event in
            calendar.component(.hour, from: event.startDate) >= 21
        }.count

        return DailyScheduleSummary(
            id: UUID(),
            date: tomorrow,
            eventCount: events.count,
            busyHours: busyHours,
            backToBackCount: backToBackCount,
            lateNightEvents: lateNightEvents
        )
    }

    func fetchTomorrowEvents() async throws -> [SupabaseService.CalendarEventPayload] {
        guard authorizationState() == .authorized else {
            throw PlatformDataError.calendarAuthorizationMissing
        }

        let events = try await fetchEventsForTomorrow()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"

        return events.enumerated().map { index, event in
            let previousEvent = index > 0 ? events[index - 1] : nil
            let isBackToBack = previousEvent.map { event.startDate.timeIntervalSince($0.endDate) <= 15 * 60 } ?? false

            return SupabaseService.CalendarEventPayload(
                title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? event.title! : "Untitled event",
                startTime: formatter.string(from: event.startDate),
                endTime: formatter.string(from: event.endDate),
                isBackToBack: isBackToBack
            )
        }
    }

    private var tomorrowStartDate: Date {
        let startOfToday = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
    }

    private func fetchEventsForTomorrow() async throws -> [EKEvent] {
        let start = tomorrowStartDate
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)

        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    private func countBackToBackTransitions(in events: [EKEvent]) -> Int {
        guard events.count > 1 else { return 0 }

        var count = 0
        for pair in zip(events, events.dropFirst()) {
            if pair.1.startDate.timeIntervalSince(pair.0.endDate) <= 15 * 60 {
                count += 1
            }
        }
        return count
    }
}
