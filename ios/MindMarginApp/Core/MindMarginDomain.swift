import Foundation

struct DailyHealthSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let sleepHours: Double
    let steps: Int
    let restingHeartRate: Double?
    let heartRateVariability: Double?
}

extension DailyHealthSummary {
    static let sample = DailyHealthSummary(
        id: UUID(),
        date: .now,
        sleepHours: 6.4,
        steps: 5_480,
        restingHeartRate: 72,
        heartRateVariability: 38
    )
}

struct DailyScheduleSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let eventCount: Int
    let busyHours: Double
    let backToBackCount: Int
    let lateNightEvents: Int
}

extension DailyScheduleSummary {
    static let sample = DailyScheduleSummary(
        id: UUID(),
        date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
        eventCount: 6,
        busyHours: 5.5,
        backToBackCount: 3,
        lateNightEvents: 1
    )
}

struct StressCheckIn: Codable, Identifiable {
    let id: UUID
    let date: Date
    let stressLevel: Int
    let energyLevel: Int
    let caffeineServings: Int
    let helpfulYesterday: Bool?
    let notes: String?
}

extension StressCheckIn {
    static let sampleHistory: [StressCheckIn] = [
        StressCheckIn(id: UUID(), date: .now.addingTimeInterval(-6 * 86_400), stressLevel: 3, energyLevel: 3, caffeineServings: 1, helpfulYesterday: true, notes: nil),
        StressCheckIn(id: UUID(), date: .now.addingTimeInterval(-5 * 86_400), stressLevel: 4, energyLevel: 2, caffeineServings: 2, helpfulYesterday: true, notes: nil),
        StressCheckIn(id: UUID(), date: .now.addingTimeInterval(-4 * 86_400), stressLevel: 5, energyLevel: 2, caffeineServings: 2, helpfulYesterday: false, notes: "Exam prep night."),
        StressCheckIn(id: UUID(), date: .now.addingTimeInterval(-3 * 86_400), stressLevel: 4, energyLevel: 3, caffeineServings: 3, helpfulYesterday: false, notes: nil),
        StressCheckIn(id: UUID(), date: .now.addingTimeInterval(-2 * 86_400), stressLevel: 3, energyLevel: 4, caffeineServings: 1, helpfulYesterday: true, notes: nil),
        StressCheckIn(id: UUID(), date: .now.addingTimeInterval(-1 * 86_400), stressLevel: 3, energyLevel: 4, caffeineServings: 1, helpfulYesterday: true, notes: nil),
    ]
}

struct StressFeatures: Codable {
    let sleepDebtHours: Double
    let sleepRegularityScore: Double
    let activityTrendScore: Double
    let scheduleIntensityScore: Double
    let recentStressAverage: Double
}

struct StressPrediction: Codable {
    enum RiskLevel: String, Codable {
        case low
        case medium
        case high

        var label: String {
            switch self {
            case .low:
                return "Low Risk"
            case .medium:
                return "Moderate Risk"
            case .high:
                return "High Risk"
            }
        }
    }

    let riskLevel: RiskLevel
    let score: Double
    let topFactors: [String]
}

extension StressPrediction {
    static let sample = StressPrediction(
        riskLevel: .high,
        score: 0.78,
        topFactors: [
            "Sleep debt has built across multiple nights.",
            "Tomorrow's calendar has several back-to-back blocks.",
            "Activity is below your recent baseline.",
            "Resting heart rate is elevated above normal."
        ]
    )
}

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
            title: "Protect your bedtime tonight",
            body: "Aim for lights out by 10:30 PM and keep your final half hour quiet.",
            rationale: "Sleep debt is your strongest risk driver right now.",
            category: "sleep"
        ),
        Recommendation(
            id: UUID(),
            title: "Add a 20-minute buffer after your second class",
            body: "Block a small recovery window before the next push starts.",
            rationale: "Your schedule is dense enough that short breaks will lower overload.",
            category: "schedule"
        ),
        Recommendation(
            id: UUID(),
            title: "Take a 10-minute walk before evening study",
            body: "Use movement to reset before you ask for more focus.",
            rationale: "Recent activity is below baseline, which tends to amplify stress.",
            category: "movement"
        )
    ]
}

protocol StressPredicting {
    func predict(from features: StressFeatures) async throws -> StressPrediction
}

protocol RecommendationProviding {
    func recommendations(for prediction: StressPrediction, features: StressFeatures) -> [Recommendation]
}

struct RuleBasedStressPredictor: StressPredicting {
    func predict(from features: StressFeatures) async throws -> StressPrediction {
        var score = 0.08
        var factors: [String] = []

        if features.sleepDebtHours > 1.5 {
            score += 0.24
            factors.append("Sleep debt has built across multiple nights.")
        }

        if features.scheduleIntensityScore > 0.65 {
            score += 0.24
            factors.append("Tomorrow's calendar has several back-to-back blocks.")
        }

        if features.activityTrendScore < 0.55 {
            score += 0.16
            factors.append("Activity is below your recent baseline.")
        }

        if features.recentStressAverage >= 4 {
            score += 0.18
            factors.append("Recent check-ins still show elevated stress.")
        }

        if features.sleepRegularityScore < 0.65 {
            score += 0.1
            factors.append("Sleep timing has been less regular than usual.")
        }

        let clampedScore = min(max(score, 0.05), 0.95)
        let riskLevel: StressPrediction.RiskLevel

        switch clampedScore {
        case ..<0.33:
            riskLevel = .low
        case ..<0.66:
            riskLevel = .medium
        default:
            riskLevel = .high
        }

        return StressPrediction(
            riskLevel: riskLevel,
            score: clampedScore,
            topFactors: factors.isEmpty ? ["No strong risk factors detected today."] : Array(factors.prefix(4))
        )
    }
}

struct RecommendationEngine: RecommendationProviding {
    func recommendations(for prediction: StressPrediction, features: StressFeatures) -> [Recommendation] {
        var items: [Recommendation] = []

        if features.sleepDebtHours > 1 {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Protect your bedtime tonight",
                    body: "Keep your last 30 minutes screen-light and work-free.",
                    rationale: "Reducing sleep drift is the fastest way to lower tomorrow's stress load.",
                    category: "sleep"
                )
            )
        }

        if features.scheduleIntensityScore > 0.6 {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Add a 20-minute buffer block",
                    body: "Place one short recovery window between your busiest commitments.",
                    rationale: "Small buffers prevent back-to-back obligations from compounding into overload.",
                    category: "schedule"
                )
            )
        }

        if features.activityTrendScore < 0.55 {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Take a 10-minute walk before the evening push",
                    body: "Use a short reset walk to bring your stress response down.",
                    rationale: "A little movement improves regulation and makes focus feel less effortful.",
                    category: "movement"
                )
            )
        }

        if prediction.riskLevel == .high || features.recentStressAverage >= 4 {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Practice a 5-minute recovery reset",
                    body: "Try box breathing or a short body scan before bed.",
                    rationale: "A brief downshift helps your nervous system recover before the next day begins.",
                    category: "recovery"
                )
            )
        }

        if items.isEmpty {
            items.append(
                Recommendation(
                    id: UUID(),
                    title: "Keep your current routine",
                    body: "Your signals look stable. Hold onto the habits that are working.",
                    rationale: "No major drivers are elevated enough to require a new intervention today.",
                    category: "general"
                )
            )
        }

        return items
    }
}

final class HealthKitClient {
    func requestAuthorization() async throws {
    }

    func fetchLatestSummary() async throws -> DailyHealthSummary {
        DailyHealthSummary(
            id: UUID(),
            date: .now,
            sleepHours: 6.8,
            steps: 7_120,
            restingHeartRate: 65,
            heartRateVariability: 42
        )
    }
}

final class CalendarClient {
    func requestAccess() async throws {
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

    func fetchTomorrowEvents() async throws -> [SupabaseService.CalendarEventPayload] {
        []
    }
}
