import Foundation
import HealthKit

enum PlatformAuthorizationState {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

final class HealthKitClient {
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var requiredReadTypes: [HKObjectType] {
        guard
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
            let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        else {
            return []
        }

        return [sleepType, stepType, restingHeartRateType, hrvType]
    }

    func authorizationState() async -> PlatformAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }

        let types = requiredReadTypes
        guard !types.isEmpty else { return .unavailable }

        let statuses = types.map { healthStore.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            return .authorized
        }

        let requestStatus = await withCheckedContinuation { (continuation: CheckedContinuation<HKAuthorizationRequestStatus, Never>) in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: Set(types)) { status, _ in
                continuation.resume(returning: status)
            }
        }

        switch requestStatus {
        case .shouldRequest, .unknown:
            return .notDetermined
        case .unnecessary:
            // For HealthKit read permissions, "unnecessary" commonly means the app
            // has already completed the request flow and should proceed with queries.
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw PlatformDataError.healthDataUnavailable
        }

        let types = requiredReadTypes
        guard !types.isEmpty else {
            throw PlatformDataError.healthDataUnavailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: Set(types))
    }

    func fetchLatestSummary() async throws -> DailyHealthSummary {
        let state = await authorizationState()
        guard state == .authorized else {
            throw PlatformDataError.healthAuthorizationMissing
        }

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let sleepWindowStart = calendar.date(byAdding: .hour, value: -18, to: startOfToday) ?? startOfToday.addingTimeInterval(-18 * 3_600)
        let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? now
        let rollingDayStart = calendar.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86_400)

        async let sleepHours = fetchSleepHours(from: sleepWindowStart, to: sleepWindowEnd)
        async let steps = fetchCumulativeQuantity(.stepCount, from: startOfToday, to: now, unit: .count())
        async let restingHeartRate = fetchAverageQuantity(.restingHeartRate, from: rollingDayStart, to: now, unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = fetchAverageQuantity(.heartRateVariabilitySDNN, from: rollingDayStart, to: now, unit: .secondUnit(with: .milli))

        return DailyHealthSummary(
            id: UUID(),
            date: now,
            sleepHours: try await sleepHours,
            steps: Int((try await steps).rounded()),
            restingHeartRate: try await restingHeartRate,
            heartRateVariability: try await hrv
        )
    }

    private func fetchSleepHours(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw PlatformDataError.healthDataUnavailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        let totalSeconds = samples
            .filter { sample in
                if #available(iOS 16.0, *) {
                    return sample.value != HKCategoryValueSleepAnalysis.awake.rawValue
                }
                return sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            }
            .reduce(0.0) { partialResult, sample in
                partialResult + sample.endDate.timeIntervalSince(sample.startDate)
            }

        return totalSeconds / 3_600
    }

    private func fetchCumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date,
        unit: HKUnit
    ) async throws -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw PlatformDataError.healthDataUnavailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchAverageQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date,
        unit: HKUnit
    ) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw PlatformDataError.healthDataUnavailable
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}

enum PlatformDataError: LocalizedError {
    case healthDataUnavailable
    case healthAuthorizationMissing
    case calendarAuthorizationMissing

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .healthAuthorizationMissing:
            return "Health access has not been granted."
        case .calendarAuthorizationMissing:
            return "Calendar access has not been granted."
        }
    }
}
