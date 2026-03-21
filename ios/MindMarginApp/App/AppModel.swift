import AuthenticationServices
import Combine
import Foundation
import SwiftUI

@MainActor
final class MindMarginAppModel: ObservableObject {
    enum OnboardingStep {
        case welcome
        case permissions
        case personalization
        case complete
    }

    enum AppTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case checkIn = "Check-In"
        case insights = "Insights"
        case settings = "Settings"

        var id: String { rawValue }

        var symbolName: String {
            switch self {
            case .dashboard:
                return "square.grid.2x2"
            case .checkIn:
                return "checklist"
            case .insights:
                return "chart.line.uptrend.xyaxis"
            case .settings:
                return "gearshape"
            }
        }
    }

    enum Route: Hashable {
        case actionPlan
    }

    enum CommunicationStyle: String, CaseIterable, Identifiable {
        case gentle = "Gentle"
        case balanced = "Balanced"
        case direct = "Direct"

        var id: String { rawValue }
    }

    enum StudentType: String, CaseIterable, Identifiable {
        case highSchool = "High School"
        case college = "College / Undergraduate"
        case graduate = "Graduate Student"

        var id: String { rawValue }
    }

    enum BackendStatus {
        case notConfigured
        case connecting
        case connected
        case localOnly(String)

        var label: String {
            switch self {
            case .notConfigured:
                return "Local only"
            case .connecting:
                return "Connecting"
            case .connected:
                return "Connected"
            case .localOnly:
                return "Fallback mode"
            }
        }

        var detail: String {
            switch self {
            case .notConfigured:
                return "Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the app environment or Info.plist to enable sync."
            case .connecting:
                return "Syncing health, schedule, and forecast data with Supabase."
            case .connected:
                return "Health summaries, schedule summaries, check-ins, and recommendations are synced with Supabase."
            case .localOnly(let reason):
                return reason
            }
        }

        var isConnected: Bool {
            if case .connected = self {
                return true
            }
            return false
        }
    }

    struct DashboardFactor: Identifiable {
        enum Impact {
            case high
            case moderate

            var label: String {
                switch self {
                case .high:
                    return "high"
                case .moderate:
                    return "moderate"
                }
            }
        }

        let id = UUID()
        let symbolName: String
        let title: String
        let value: String
        let tint: Color
        let impact: Impact
    }

    struct InsightPoint: Identifiable {
        let id = UUID()
        let date: Date
        let label: String
        let primary: Double
        let secondary: Double?
    }

    @Published var onboardingStep: OnboardingStep = .welcome
    @Published var selectedTab: AppTab = .dashboard
    @Published var navigationPath: [Route] = []

    @Published var isHealthAuthorized = false
    @Published var isCalendarAuthorized = false

    @Published var reminderTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    @Published var communicationStyle: CommunicationStyle = .balanced
    @Published var studentType: StudentType = .college

    @Published var stressLevel = 3
    @Published var energyLevel = 2
    @Published var caffeineServings = 2
    @Published var helpfulYesterday: Bool?
    @Published var notes = ""
    @Published var isSubmittingCheckIn = false
    @Published var isRefreshingForecast = false

    @Published private(set) var healthSummary = DailyHealthSummary.sample
    @Published private(set) var scheduleSummary = DailyScheduleSummary.sample
    @Published private(set) var prediction = StressPrediction.sample
    @Published private(set) var recommendations: [Recommendation] = []
    @Published private(set) var checkInHistory: [StressCheckIn] = []
    @Published private(set) var healthHistory: [DailyHealthSummary] = []
    @Published private(set) var scheduleHistory: [DailyScheduleSummary] = []
    @Published private(set) var dashboardFactors: [DashboardFactor] = []
    @Published private(set) var completedRecommendationIDs: Set<UUID> = []
    @Published private(set) var backendStatus: BackendStatus = .notConfigured
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSavedCheckInMessage: String?

    let healthKitClient: HealthKitClient
    let calendarClient: CalendarClient
    let predictionService: any StressPredicting
    let recommendationService: any RecommendationProviding
    let supabaseService: SupabaseService?

    private var hasBootstrapped = false
    private var hasAttemptedBackendSignIn = false

    init() {
        self.healthKitClient = HealthKitClient()
        self.calendarClient = CalendarClient()
        self.predictionService = RuleBasedStressPredictor()
        self.recommendationService = RecommendationEngine()
        self.supabaseService = SupabaseConfiguration.load().map { SupabaseService(configuration: $0) }
        self.recommendations = Recommendation.sampleData
        self.dashboardFactors = Self.makeFallbackFactors(from: healthSummary, schedule: scheduleSummary)
        self.checkInHistory = []
        self.healthHistory = [healthSummary]
        self.scheduleHistory = [scheduleSummary]
    }

    init(
        healthKitClient: HealthKitClient,
        calendarClient: CalendarClient,
        predictionService: any StressPredicting,
        recommendationService: any RecommendationProviding,
        supabaseService: SupabaseService?
    ) {
        self.healthKitClient = healthKitClient
        self.calendarClient = calendarClient
        self.predictionService = predictionService
        self.recommendationService = recommendationService
        self.supabaseService = supabaseService
        self.recommendations = Recommendation.sampleData
        self.dashboardFactors = Self.makeFallbackFactors(from: healthSummary, schedule: scheduleSummary)
        self.checkInHistory = []
        self.healthHistory = [healthSummary]
        self.scheduleHistory = [scheduleSummary]
    }

    var isOnboardingComplete: Bool {
        onboardingStep == .complete
    }

    var permissionsReady: Bool {
        isHealthAuthorized && isCalendarAuthorized
    }

    var riskScoreOutOf100: Int {
        Int((prediction.score * 100).rounded())
    }

    var dashboardDateLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var forecastSummary: String {
        switch prediction.riskLevel {
        case .low:
            return "Tomorrow looks manageable. Keep your routine steady and protect your recovery windows."
        case .medium:
            return "Tomorrow has a few pressure points. A little sleep protection and schedule spacing should help."
        case .high:
            return "Tomorrow looks stressful. Sleep debt and a dense schedule are your biggest risk drivers."
        }
    }

    var checkInStreak: Int {
        guard !checkInHistory.isEmpty else { return 0 }

        let calendar = Calendar.current
        let orderedDays = checkInHistory
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        for day in orderedDays {
            if calendar.isDate(day, inSameDayAs: cursor) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previousDay
            } else if day < cursor {
                break
            }
        }

        return streak
    }

    var checkInProgress: Double {
        min(Double(checkInStreak) / 7.0, 1.0)
    }

    var reminderTimeLabel: String {
        reminderTime.formatted(date: .omitted, time: .shortened)
    }

    var insightStressTrend: [InsightPoint] {
        checkInHistory
            .suffix(7)
            .map { InsightPoint(date: $0.date, label: weekdayLabel(for: $0.date), primary: Double($0.stressLevel), secondary: nil) }
    }

    var insightSleepVsStress: [InsightPoint] {
        let recentHealth = healthHistory.suffix(7)

        return recentHealth.map { health in
            let stress = checkInHistory.first(where: { Calendar.current.isDate($0.date, inSameDayAs: health.date) })
            return InsightPoint(
                date: health.date,
                label: shortWeekdayLabel(for: health.date),
                primary: health.sleepHours,
                secondary: stress.map { Double($0.stressLevel) }
            )
        }
    }

    var insightScheduleDensity: [InsightPoint] {
        scheduleHistory
            .suffix(7)
            .map { InsightPoint(date: $0.date, label: weekdayLabel(for: $0.date), primary: Double($0.eventCount), secondary: nil) }
    }

    var averageStressLabel: String {
        guard !checkInHistory.isEmpty else { return "--" }
        return checkInHistory
            .suffix(7)
            .map(\.stressLevel)
            .average
            .formatted(.number.precision(.fractionLength(1)))
    }

    var averageStressChangeLabel: String {
        percentageChangeLabel(
            current: checkInHistory.suffix(7).map(\.stressLevel).average,
            previous: Array(checkInHistory.dropLast(min(7, checkInHistory.count)).suffix(7)).map(\.stressLevel).average,
            positiveIsGood: false
        )
    }

    var averageSleepLabel: String {
        guard !healthHistory.isEmpty else { return "--" }
        let average = healthHistory.suffix(7).map(\.sleepHours).averageDouble
        return "\(average.formatted(.number.precision(.fractionLength(1))))h"
    }

    var averageSleepChangeLabel: String {
        percentageChangeLabel(
            current: healthHistory.suffix(7).map(\.sleepHours).averageDouble,
            previous: Array(healthHistory.dropLast(min(7, healthHistory.count)).suffix(7)).map(\.sleepHours).averageDouble,
            positiveIsGood: true
        )
    }

    var insightPatterns: [InsightPattern] {
        var patterns: [InsightPattern] = []

        if let sleepPattern = sleepPatternInsight {
            patterns.append(sleepPattern)
        }

        if let schedulePattern = schedulePatternInsight {
            patterns.append(schedulePattern)
        }

        if let energyPattern = energyPatternInsight {
            patterns.append(energyPattern)
        }

        if patterns.isEmpty {
            patterns.append(
                InsightPattern(
                    symbolName: "waveform.path.ecg",
                    tint: MindMarginTheme.indigo,
                    background: MindMarginTheme.indigo.opacity(0.12),
                    title: "More history unlocks stronger patterns",
                    description: "Keep syncing check-ins and daily summaries to build trend-based guidance."
                )
            )
        }

        return patterns
    }

    struct InsightPattern: Identifiable {
        let id = UUID()
        let symbolName: String
        let tint: Color
        let background: Color
        let title: String
        let description: String
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        do {
            try await connectBackendIfNeeded()
        } catch {
            backendStatus = .localOnly("Using local mode because Supabase sign-in failed: \(error.localizedDescription)")
        }
        await refreshForecast()
    }

    func advanceFromWelcome() {
        onboardingStep = .permissions
    }

    func continueFromPermissions() {
        guard permissionsReady else { return }
        onboardingStep = .personalization
    }

    func finishOnboarding() {
        onboardingStep = .complete

        Task {
            await syncProfilePreferences()
        }
    }

    func openActionPlan() {
        navigationPath.append(.actionPlan)
    }

    func dismissSavedMessage() {
        lastSavedCheckInMessage = nil
    }

    func dismissError() {
        errorMessage = nil
    }

    func signInWithApple(idToken: String, rawNonce: String?) async {
        guard let supabaseService else {
            errorMessage = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            return
        }
        errorMessage = nil
        do {
            try await supabaseService.signInWithApple(idToken: idToken, rawNonce: rawNonce)
            hasAttemptedBackendSignIn = true
            backendStatus = .connected
            await refreshForecast()
        } catch {
            backendStatus = .localOnly("Sign in failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle() async {
        guard let supabaseService else {
            errorMessage = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            return
        }
        errorMessage = nil
        do {
            try await supabaseService.signInWithGoogle()
            hasAttemptedBackendSignIn = true
            backendStatus = .connected
            await refreshForecast()
        } catch {
            let ns = error as NSError
            if ns.domain == ASWebAuthenticationSessionErrorDomain, ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            backendStatus = .localOnly("Google sign-in failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func signOutFromBackend() {
        supabaseService?.signOut()
        hasAttemptedBackendSignIn = false
        if supabaseService != nil {
            backendStatus = .localOnly("Signed out. Cloud sync is off until you sign in again.")
        } else {
            backendStatus = .notConfigured
        }
    }

    func grantHealthAccess() {
        Task {
            do {
                try await healthKitClient.requestAuthorization()
                isHealthAuthorized = true
                await refreshForecast()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func grantCalendarAccess() {
        Task {
            do {
                try await calendarClient.requestAccess()
                isCalendarAuthorized = true
                await refreshForecast()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveCheckIn() {
        Task {
            isSubmittingCheckIn = true
            errorMessage = nil

            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let checkIn = StressCheckIn(
                id: UUID(),
                date: .now,
                stressLevel: stressLevel,
                energyLevel: energyLevel,
                caffeineServings: caffeineServings,
                helpfulYesterday: helpfulYesterday,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )

            append(checkIn)

            do {
                if let supabaseService {
                    try await connectBackendIfNeeded()
                    if supabaseService.isAuthenticated {
                        try await supabaseService.syncCheckIn(checkIn)
                        checkInHistory = try await supabaseService.fetchCheckIns()
                        backendStatus = .connected
                    }
                }
            } catch {
                backendStatus = .localOnly("Check-in saved locally. Supabase sync failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            await refreshForecast()

            isSubmittingCheckIn = false
            lastSavedCheckInMessage = "Today's check-in was saved. Forecast updated."
            notes = ""
        }
    }

    func isRecommendationCompleted(_ recommendation: Recommendation) -> Bool {
        completedRecommendationIDs.contains(recommendation.id)
    }

    func toggleRecommendation(_ recommendation: Recommendation) {
        if completedRecommendationIDs.contains(recommendation.id) {
            completedRecommendationIDs.remove(recommendation.id)
        } else {
            completedRecommendationIDs.insert(recommendation.id)
        }
    }

    func refreshForecast() async {
        guard !isRefreshingForecast else { return }
        isRefreshingForecast = true
        errorMessage = nil

        do {
            healthSummary = try await healthKitClient.fetchLatestSummary()
            scheduleSummary = try await calendarClient.fetchTomorrowSummary()
            append(healthSummary)
            append(scheduleSummary)

            let features = makeFeatures(from: healthSummary, schedule: scheduleSummary)
            let localPrediction = try await predictionService.predict(from: features)
            let localRecommendations = recommendationService.recommendations(for: localPrediction, features: features)

            prediction = localPrediction
            recommendations = localRecommendations
            dashboardFactors = Self.makeFallbackFactors(from: healthSummary, schedule: scheduleSummary)

            if let supabaseService {
                do {
                    try await connectBackendIfNeeded()

                    if supabaseService.isAuthenticated {
                        try await supabaseService.syncHealthSummary(healthSummary)
                        try await supabaseService.syncScheduleSummary(scheduleSummary)

                        let events = try await calendarClient.fetchTomorrowEvents()
                        let analysis = try await supabaseService.analyzeStress(for: scheduleSummary.date, calendarEvents: events)

                        prediction = analysis.prediction
                        recommendations = analysis.recommendations.isEmpty ? localRecommendations : analysis.recommendations
                        dashboardFactors = Self.makeDashboardFactors(
                            from: analysis.factorScores,
                            health: healthSummary,
                            schedule: scheduleSummary
                        )
                        healthHistory = try await supabaseService.fetchHealthSummaries()
                        scheduleHistory = try await supabaseService.fetchScheduleSummaries()
                        checkInHistory = try await supabaseService.fetchCheckIns()
                        backendStatus = .connected
                    }
                } catch {
                    backendStatus = .localOnly("Using local prediction only because Supabase sync failed: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }

            ensureLocalHistoriesExist()
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshingForecast = false
    }

    private func connectBackendIfNeeded() async throws {
        guard let supabaseService else {
            backendStatus = .notConfigured
            return
        }

        if supabaseService.isAuthenticated {
            backendStatus = .connected
            return
        }

        await supabaseService.restoreSessionIfNeeded()
        if supabaseService.isAuthenticated {
            backendStatus = .connected
            return
        }

        guard !hasAttemptedBackendSignIn else { return }
        hasAttemptedBackendSignIn = true
        backendStatus = .connecting
        try await supabaseService.signInAnonymouslyIfNeeded()
        backendStatus = .connected
    }

    private func syncProfilePreferences() async {
        guard let supabaseService else { return }

        do {
            try await connectBackendIfNeeded()
            guard supabaseService.isAuthenticated else { return }
            try await supabaseService.upsertProfile(
                reminderTime: reminderTime.formatted(date: .omitted, time: .shortened),
                preferredInterventionStyle: communicationStyle.rawValue
            )
            backendStatus = .connected
        } catch {
            backendStatus = .localOnly("Preferences were updated locally. Supabase profile sync failed: \(error.localizedDescription)")
        }
    }

    private func makeFeatures(from health: DailyHealthSummary, schedule: DailyScheduleSummary) -> StressFeatures {
        let recentAverage = checkInHistory
            .suffix(5)
            .map(\.stressLevel)
            .average

        let sleepDebtHours = max(0, 7.8 - health.sleepHours)
        let sleepRegularityScore = min(max(health.sleepHours / 8.0, 0.35), 0.95)
        let activityTrendScore = min(max(Double(health.steps) / 9_000.0, 0.2), 1.0)
        let scheduleIntensityScore = min(
            (Double(schedule.eventCount) * 0.08)
                + (schedule.busyHours * 0.06)
                + (Double(schedule.backToBackCount) * 0.12)
                + (Double(schedule.lateNightEvents) * 0.08),
            1.0
        )

        return StressFeatures(
            sleepDebtHours: sleepDebtHours,
            sleepRegularityScore: sleepRegularityScore,
            activityTrendScore: activityTrendScore,
            scheduleIntensityScore: scheduleIntensityScore,
            recentStressAverage: recentAverage
        )
    }

    private func append(_ summary: DailyHealthSummary) {
        healthHistory = upsertByDay(summary, into: healthHistory)
    }

    private func append(_ summary: DailyScheduleSummary) {
        scheduleHistory = upsertByDay(summary, into: scheduleHistory)
    }

    private func append(_ checkIn: StressCheckIn) {
        let filtered = checkInHistory.filter { !Calendar.current.isDate($0.date, inSameDayAs: checkIn.date) }
        checkInHistory = (filtered + [checkIn]).sorted { $0.date < $1.date }
    }

    private func ensureLocalHistoriesExist() {
        if healthHistory.isEmpty {
            healthHistory = [healthSummary]
        }

        if scheduleHistory.isEmpty {
            scheduleHistory = [scheduleSummary]
        }
    }

    private func upsertByDay<T>(_ value: T, into existing: [T]) -> [T] where T: Identifiable {
        let calendar = Calendar.current
        let updated = existing.filter {
            guard let currentDate = Self.date(for: $0), let newDate = Self.date(for: value) else { return true }
            return !calendar.isDate(currentDate, inSameDayAs: newDate)
        } + [value]

        return updated.sorted {
            guard let left = Self.date(for: $0), let right = Self.date(for: $1) else { return false }
            return left < right
        }
    }

    private static func date(for value: some Identifiable) -> Date? {
        switch value {
        case let health as DailyHealthSummary:
            return health.date
        case let schedule as DailyScheduleSummary:
            return schedule.date
        default:
            return nil
        }
    }

    private static func makeDashboardFactors(
        from factorScores: SupabaseService.FactorScores?,
        health: DailyHealthSummary,
        schedule: DailyScheduleSummary
    ) -> [DashboardFactor] {
        guard let factorScores else {
            return makeFallbackFactors(from: health, schedule: schedule)
        }

        return [
            DashboardFactor(
                symbolName: "moon.zzz.fill",
                title: "Sleep load",
                value: factorScores.sleep?.rawHours.map { "\($0.formatted(.number.precision(.fractionLength(1))))h sleep" } ?? "\(health.sleepHours.formatted(.number.precision(.fractionLength(1))))h sleep",
                tint: MindMarginTheme.red,
                impact: (factorScores.sleep?.score ?? 0) >= 1.4 ? .high : .moderate
            ),
            DashboardFactor(
                symbolName: "calendar",
                title: "Schedule pressure",
                value: "\(schedule.eventCount) events, \(schedule.busyHours.formatted(.number.precision(.fractionLength(1))))h busy",
                tint: MindMarginTheme.yellow,
                impact: (factorScores.schedule?.score ?? 0) >= 0.8 ? .high : .moderate
            ),
            DashboardFactor(
                symbolName: "figure.walk",
                title: "Activity",
                value: "\(health.steps.formatted()) steps",
                tint: MindMarginTheme.green,
                impact: (factorScores.activity?.score ?? 0) >= 0.9 ? .high : .moderate
            ),
            DashboardFactor(
                symbolName: "heart.fill",
                title: "Recovery markers",
                value: recoveryValue(from: factorScores, health: health),
                tint: MindMarginTheme.orange,
                impact: ((factorScores.hrv?.score ?? 0) + (factorScores.restingHR?.score ?? 0)) >= 1.0 ? .high : .moderate
            ),
        ]
    }

    private static func makeFallbackFactors(from health: DailyHealthSummary, schedule: DailyScheduleSummary) -> [DashboardFactor] {
        [
            DashboardFactor(
                symbolName: "moon.zzz.fill",
                title: "Sleep debt",
                value: "\(max(Int(round(7.8 - health.sleepHours)), 1)) nights",
                tint: MindMarginTheme.red,
                impact: .high
            ),
            DashboardFactor(
                symbolName: "calendar",
                title: "Dense schedule",
                value: "\(schedule.eventCount) events",
                tint: MindMarginTheme.yellow,
                impact: .high
            ),
            DashboardFactor(
                symbolName: "figure.walk",
                title: "Reduced activity",
                value: health.steps < 6_000 ? "Below baseline" : "Near baseline",
                tint: MindMarginTheme.green,
                impact: .moderate
            ),
            DashboardFactor(
                symbolName: "heart.fill",
                title: "Elevated HR",
                value: "\(Int(health.restingHeartRate ?? 70)) bpm",
                tint: MindMarginTheme.orange,
                impact: .moderate
            ),
        ]
    }

    private static func recoveryValue(from factorScores: SupabaseService.FactorScores, health: DailyHealthSummary) -> String {
        if let hrv = factorScores.hrv?.rawMilliseconds {
            return "HRV \(Int(hrv)) ms"
        }

        if let restingHR = factorScores.restingHR?.rawBPM {
            return "\(Int(restingHR)) bpm"
        }

        return "\(Int(health.restingHeartRate ?? 70)) bpm"
    }

    private func percentageChangeLabel(current: Double, previous: Double, positiveIsGood: Bool) -> String {
        guard previous > 0 else { return "New" }
        let delta = ((current - previous) / previous) * 100
        let rounded = Int(delta.rounded())

        if rounded == 0 {
            return "0%"
        }

        let sign = rounded > 0 ? "+" : ""
        let output = "\(sign)\(rounded)%"

        if positiveIsGood {
            return output
        }

        return rounded <= 0 ? output : "+\(abs(rounded))%"
    }

    private func weekdayLabel(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func shortWeekdayLabel(for date: Date) -> String {
        String(weekdayLabel(for: date).prefix(1))
    }

    private var sleepPatternInsight: InsightPattern? {
        let paired = insightSleepVsStress.compactMap { point -> (sleep: Double, stress: Double)? in
            guard let stress = point.secondary else { return nil }
            return (point.primary, stress)
        }

        guard paired.count >= 3 else { return nil }

        let shortSleepDays = paired.filter { $0.sleep < 7 && $0.stress >= 4 }.count
        guard shortSleepDays >= 2 else { return nil }

        return InsightPattern(
            symbolName: "moon.stars.fill",
            tint: Color(hex: 0x7C3AED),
            background: Color(hex: 0xEDE9FE),
            title: "Short sleep tracks with higher stress",
            description: "In your recent data, nights under 7 hours usually line up with next-day stress ratings of 4 or 5."
        )
    }

    private var schedulePatternInsight: InsightPattern? {
        let denseDays = scheduleHistory.suffix(7).filter { $0.eventCount >= 5 || $0.backToBackCount >= 2 }
        guard denseDays.count >= 2 else { return nil }

        return InsightPattern(
            symbolName: "calendar",
            tint: MindMarginTheme.blue,
            background: Color(hex: 0xDBEAFE),
            title: "Busy days are your clearest pressure point",
            description: "Your schedule history shows repeated high-density days, so buffer time is likely to have the biggest impact."
        )
    }

    private var energyPatternInsight: InsightPattern? {
        let lowEnergyDays = checkInHistory.suffix(7).filter { $0.energyLevel <= 2 }
        guard lowEnergyDays.count >= 2 else { return nil }

        return InsightPattern(
            symbolName: "bolt.fill",
            tint: MindMarginTheme.green,
            background: Color(hex: 0xD1FAE5),
            title: "Low-energy days deserve lighter plans",
            description: "You have had multiple low-energy check-ins recently, which is a strong signal to reduce stacking and recovery debt."
        )
    }
}

private extension Array where Element == Int {
    var average: Double {
        guard !isEmpty else { return 2.5 }
        return Double(reduce(0, +)) / Double(count)
    }
}

private extension Array where Element == Double {
    var averageDouble: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
