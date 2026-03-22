import AuthenticationServices
import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MindMarginAppModel: ObservableObject {
    enum OnboardingStep {
        case welcome
        case authentication
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

    enum DemoScenario: String, CaseIterable, Identifiable {
        case calmDay
        case packedDay
        case examWeek

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calmDay:
                return "Calm Day"
            case .packedDay:
                return "Packed Day"
            case .examWeek:
                return "Exam Week"
            }
        }

        var summary: String {
            switch self {
            case .calmDay:
                return "Light classes, strong recovery, and stable biometrics for a low-risk walkthrough."
            case .packedDay:
                return "A busy day with back-to-back commitments and tighter recovery windows."
            case .examWeek:
                return "High academic pressure, weaker biometrics, and a late study schedule for a high-risk demo."
            }
        }
    }

    private struct DemoScenarioSnapshot {
        let healthSummary: DailyHealthSummary
        let scheduleSummary: DailyScheduleSummary
        let calendarEvents: [SupabaseService.CalendarEventPayload]
        let checkIns: [StressCheckIn]
        let healthHistory: [DailyHealthSummary]
        let scheduleHistory: [DailyScheduleSummary]
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
            case low

            var label: String {
                switch self {
                case .high:
                    return "high"
                case .moderate:
                    return "moderate"
                case .low:
                    return "low"
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



    struct ScheduleDisplayBlock: Identifiable {
        enum Kind {
            case event
            case recommendation
        }

        let id = UUID()
        let kind: Kind
        let title: String
        let subtitle: String
        let startLabel: String
        let endLabel: String
        let tint: Color
    }

    @Published var onboardingStep: OnboardingStep = .welcome
    @Published var selectedTab: AppTab = .dashboard
    @Published var navigationPath: [Route] = []

    @Published var isHealthAuthorized = false
    @Published var isCalendarAuthorized = false
    @Published private(set) var healthAuthorizationState: PlatformAuthorizationState = .notDetermined
    @Published private(set) var calendarAuthorizationState: PlatformAuthorizationState = .notDetermined

    @Published var reminderTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    @Published var communicationStyle: CommunicationStyle = .balanced
    @Published var studentType: StudentType = .college

    @Published var stressLevel = 3
    @Published var energyLevel = 3
    @Published var caffeineServings = 0
    @Published var helpfulYesterday: Bool?
    @Published var notes = ""
    @Published var isSubmittingCheckIn = false
    @Published var isRefreshingForecast = false
    @Published private(set) var isDemoModeEnabled = false
    @Published private(set) var selectedDemoScenario: DemoScenario = .packedDay

    @Published private(set) var healthSummary = DailyHealthSummary.empty
    @Published private(set) var scheduleSummary = DailyScheduleSummary.empty
    @Published private(set) var prediction = StressPrediction.empty
    @Published private(set) var recommendations: [Recommendation] = []
    @Published private(set) var checkInHistory: [StressCheckIn] = []
    @Published private(set) var healthHistory: [DailyHealthSummary] = []
    @Published private(set) var scheduleHistory: [DailyScheduleSummary] = []
    @Published private(set) var dashboardFactors: [DashboardFactor] = []
    @Published private(set) var scheduleDisplayBlocks: [ScheduleDisplayBlock] = []
    @Published private(set) var recommendationFeedbackDraftByID: [UUID: RecommendationFeedback] = [:]
    @Published private(set) var submittedRecommendationFeedbackByID: [UUID: RecommendationFeedback] = [:]
    @Published private(set) var backendStatus: BackendStatus = .notConfigured
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSavedCheckInMessage: String?
    @Published private(set) var healthPermissionHelpMessage: String?
    @Published private(set) var isAuthenticating = false

    @Published var accountName = ""
    @Published var accountEmail = ""
    @Published var accountPassword = ""

    let healthKitClient: HealthKitClient
    let calendarClient: CalendarClient
    let predictionService: any StressPredicting
    let recommendationService: any RecommendationProviding
    let supabaseService: SupabaseService?

    private var hasBootstrapped = false
    private var hasAttemptedBackendSignIn = false
    private static let demoModeEnabledKey = "mindmargin.demoModeEnabled"
    private static let demoScenarioKey = "mindmargin.demoScenario"

    private static let demoModeEnabledKey = "mindmargin.demoModeEnabled"
    private static let demoScenarioKey = "mindmargin.demoScenario"

    init() {
        let defaults = UserDefaults.standard
        self.isDemoModeEnabled = defaults.bool(forKey: Self.demoModeEnabledKey)
        self.selectedDemoScenario = defaults.string(forKey: Self.demoScenarioKey).flatMap(DemoScenario.init(rawValue:)) ?? .packedDay
        self.healthKitClient = HealthKitClient()
        self.calendarClient = CalendarClient()
        self.predictionService = RuleBasedStressPredictor()
        self.recommendationService = RecommendationEngine()
        self.supabaseService = SupabaseConfiguration.load().map { SupabaseService(configuration: $0) }
        self.recommendations = []
        self.dashboardFactors = []
        self.checkInHistory = []
        self.healthHistory = []
        self.scheduleHistory = []
    }

    init(
        healthKitClient: HealthKitClient,
        calendarClient: CalendarClient,
        predictionService: any StressPredicting,
        recommendationService: any RecommendationProviding,
        supabaseService: SupabaseService?
    ) {
        let defaults = UserDefaults.standard
        self.isDemoModeEnabled = defaults.bool(forKey: Self.demoModeEnabledKey)
        self.selectedDemoScenario = defaults.string(forKey: Self.demoScenarioKey).flatMap(DemoScenario.init(rawValue:)) ?? .packedDay
        self.healthKitClient = healthKitClient
        self.calendarClient = calendarClient
        self.predictionService = predictionService
        self.recommendationService = recommendationService
        self.supabaseService = supabaseService
        self.recommendations = []
        self.dashboardFactors = []
        self.checkInHistory = []
        self.healthHistory = []
        self.scheduleHistory = []
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

    var demoModeLabel: String {
        isDemoModeEnabled ? "On" : "Off"
    }

    var demoScenarioLabel: String {
        selectedDemoScenario.title
    }

    var demoModeSummary: String {
        if isDemoModeEnabled {
            return selectedDemoScenario.summary
        }
        return "Use simulated health, schedule, and check-in data while keeping the current forecast and recommendation flow."
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
                primary: health.sleepHours ?? 0,
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
        let average = healthHistory.suffix(7).compactMap(\.sleepHours).averageDouble
        return "\(average.formatted(.number.precision(.fractionLength(1))))h"
    }

    var averageSleepChangeLabel: String {
        percentageChangeLabel(
            current: healthHistory.suffix(7).compactMap(\.sleepHours).averageDouble,
            previous: Array(healthHistory.dropLast(min(7, healthHistory.count)).suffix(7)).compactMap(\.sleepHours).averageDouble,
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
        await refreshAuthorizationStates()
        do {
            try await connectBackendIfNeeded()
        } catch {
            backendStatus = .localOnly(
                "Supabase sign-in failed: \(error.localizedDescription). Put SUPABASE_URL and SUPABASE_ANON_KEY in the Run scheme (not backend/.env), enable Anonymous or Email under Authentication → Providers, and confirm the anon key matches your project."
            )
        }

        if let supabaseService, supabaseService.isAuthenticated {
            await StressNotificationManager.shared.syncPendingDeviceTokenIfPossible(using: supabaseService)
            await loadExistingDataFromBackend(supabaseService)
        }

        await refreshForecast()
    }

    private func loadExistingDataFromBackend(_ supa: SupabaseService) async {
        do {
            let fetchedHealth = try await supa.fetchHealthSummaries()
            let fetchedSchedule = try await supa.fetchScheduleSummaries()
            let fetchedCheckIns = try await supa.fetchCheckIns()

            applyBackendSnapshot(
                healthSummaries: fetchedHealth,
                scheduleSummaries: fetchedSchedule,
                checkIns: fetchedCheckIns
            )

            dashboardFactors = Self.makeFallbackFactors(from: healthSummary, schedule: scheduleSummary)
            scheduleDisplayBlocks = []

            do {
                let targetDate = scheduleSummary.date
                let analysis = try await supa.analyzeStress(
                    for: targetDate,
                    recommendationFeedback: makeRecommendationFeedbackPayloads()
                )
                prediction = analysis.prediction
                if !analysis.recommendations.isEmpty {
                    recommendations = analysis.recommendations
                }
                scheduleDisplayBlocks = Self.makeScheduleDisplayBlocks(
                    from: [],
                    recommendations: recommendations
                )
                if let fs = analysis.factorScores {
                    dashboardFactors = Self.makeDashboardFactors(
                        from: fs,
                        health: healthSummary,
                        schedule: scheduleSummary
                    )
                }
            } catch {
                let features = makeFeatures(from: healthSummary, schedule: scheduleSummary)
                if let localPrediction = try? await predictionService.predict(from: features) {
                    prediction = localPrediction
                    recommendations = recommendationService.recommendations(for: localPrediction, features: features)
                }
            }

            backendStatus = .connected
        } catch {
            backendStatus = .localOnly("Could not load existing data: \(error.localizedDescription)")
        }
    }

    func reloadFromDatabase() async {
        guard !isRefreshingForecast else { return }
        if isDemoModeEnabled {
            await refreshForecast()
            return
        }
        guard let supabaseService, supabaseService.isAuthenticated else {
            errorMessage = "Not connected to Supabase."
            return
        }
        isRefreshingForecast = true
        errorMessage = nil
        await loadExistingDataFromBackend(supabaseService)
        isRefreshingForecast = false
    }

    func advanceFromWelcome() {
        onboardingStep = .authentication
    }

    func signUpWithEmail(name: String, email: String, password: String) {
        Task {
            guard let supabaseService else {
                errorMessage = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
                return
            }

            isAuthenticating = true
            errorMessage = nil

            do {
                try await supabaseService.signUp(email: email, password: password)
                try await supabaseService.upsertProfile(
                    reminderTime: reminderTime.formatted(date: .omitted, time: .shortened),
                    preferredInterventionStyle: communicationStyle.rawValue,
                    userName: name,
                    email: email,
                    password: password
                )
                accountName = name
                accountEmail = email
                accountPassword = password
                hasAttemptedBackendSignIn = true
                backendStatus = .connected
                await StressNotificationManager.shared.syncPendingDeviceTokenIfPossible(using: supabaseService)
                onboardingStep = permissionsReady ? .complete : .permissions
                if permissionsReady {
                    await syncProfilePreferences()
                }
            } catch {
                backendStatus = .localOnly("Account creation failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            isAuthenticating = false
        }
    }

    func signInWithEmail(email: String, password: String) {
        Task {
            guard let supabaseService else {
                errorMessage = "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
                return
            }

            isAuthenticating = true
            errorMessage = nil

            do {
                try await supabaseService.signIn(email: email, password: password)
                accountEmail = email
                accountPassword = password
                hasAttemptedBackendSignIn = true
                backendStatus = .connected
                await StressNotificationManager.shared.syncPendingDeviceTokenIfPossible(using: supabaseService)
                onboardingStep = permissionsReady ? .complete : .permissions
                if permissionsReady {
                    await syncProfilePreferences()
                }
            } catch {
                backendStatus = .localOnly("Log in failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }

            isAuthenticating = false
        }
    }

    func continueFromPermissions() {
        guard permissionsReady else { return }
        finishOnboarding()
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

    func dismissHealthPermissionHelpMessage() {
        healthPermissionHelpMessage = nil
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
            await StressNotificationManager.shared.syncPendingDeviceTokenIfPossible(using: supabaseService)
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
            await StressNotificationManager.shared.syncPendingDeviceTokenIfPossible(using: supabaseService)
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
                let stateBeforeRequest = await healthKitClient.authorizationState()
                if stateBeforeRequest == .denied {
                    healthPermissionHelpMessage = "Health access is managed in the Health app, not the Settings app. Open Health > Sharing > Apps > MindMargin and allow the data types there."
                    errorMessage = nil
                    return
                }
                if stateBeforeRequest == .unavailable {
                    healthPermissionHelpMessage = "Health data is not available on this device. Test Health access on an iPhone with the Health app enabled."
                    errorMessage = nil
                    return
                }
                try await healthKitClient.requestAuthorization()
                await refreshAuthorizationStates()
                if permissionsReady {
                    await refreshForecast()
                } else if healthAuthorizationState == .denied {
                    healthPermissionHelpMessage = "Health access is still off. Open Health > Sharing > Apps > MindMargin and enable the requested categories."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func grantCalendarAccess() {
        Task {
            do {
                if calendarClient.authorizationState() == .denied {
                    openAppSettings()
                    return
                }
                try await calendarClient.requestAccess()
                await refreshAuthorizationStates()
                if permissionsReady {
                    await refreshForecast()
                } else if calendarAuthorizationState == .denied {
                    errorMessage = "Calendar access is still off. Enable it in the Settings app to use live schedule data."
                }
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

    func recommendationFeedbackDraft(for recommendation: Recommendation) -> RecommendationFeedback? {
        recommendationFeedbackDraftByID[recommendation.id]
            ?? submittedRecommendationFeedbackByID[recommendation.id]
    }

    func submittedRecommendationFeedback(for recommendation: Recommendation) -> RecommendationFeedback? {
        submittedRecommendationFeedbackByID[recommendation.id]
    }

    func selectRecommendationFeedback(_ feedback: RecommendationFeedback, for recommendation: Recommendation) {
        recommendationFeedbackDraftByID[recommendation.id] = feedback
    }

    func canSubmitRecommendationFeedback(for recommendation: Recommendation) -> Bool {
        guard let draft = recommendationFeedbackDraftByID[recommendation.id]
            ?? submittedRecommendationFeedbackByID[recommendation.id] else {
            return false
        }
        return submittedRecommendationFeedbackByID[recommendation.id] != draft
    }

    func submitRecommendationFeedback(for recommendation: Recommendation) {
        guard let feedback = recommendationFeedbackDraftByID[recommendation.id]
            ?? submittedRecommendationFeedbackByID[recommendation.id] else {
            return
        }
        submittedRecommendationFeedbackByID[recommendation.id] = feedback
        recommendationFeedbackDraftByID[recommendation.id] = feedback
    }

    func setDemoModeEnabled(_ enabled: Bool) {
        guard isDemoModeEnabled != enabled else { return }
        isDemoModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.demoModeEnabledKey)
        Task { await refreshForecast() }
    }

    func selectDemoScenario(_ scenario: DemoScenario) {
        guard selectedDemoScenario != scenario else { return }
        selectedDemoScenario = scenario
        UserDefaults.standard.set(scenario.rawValue, forKey: Self.demoScenarioKey)
        if isDemoModeEnabled {
            Task { await refreshForecast() }
        }
    }

    func refreshForecast() async {
        guard !isRefreshingForecast else { return }
        isRefreshingForecast = true
        errorMessage = nil

        let healthState = await healthKitClient.authorizationState()
        let calendarState = calendarClient.authorizationState()
        print("[MindMargin] refreshForecast — demoMode=\(isDemoModeEnabled) healthAuth=\(healthState) calendarAuth=\(calendarState) permissionsReady=\(permissionsReady)")

        var calendarEventsForAnalysis: [SupabaseService.CalendarEventPayload] = []

        if isDemoModeEnabled {
            let snapshot = Self.makeDemoScenarioSnapshot(for: selectedDemoScenario)
            healthSummary = snapshot.healthSummary
            scheduleSummary = snapshot.scheduleSummary
            checkInHistory = snapshot.checkIns
            healthHistory = snapshot.healthHistory
            scheduleHistory = snapshot.scheduleHistory
            calendarEventsForAnalysis = snapshot.calendarEvents
            print("[MindMargin] Demo scenario → \(selectedDemoScenario.title) events=\(scheduleSummary.eventCount) sleep=\(String(describing: healthSummary.sleepHours)) steps=\(healthSummary.steps)")
        } else if permissionsReady {
            do {
                healthSummary = try await healthKitClient.fetchLatestSummary()
                append(healthSummary)
                print("[MindMargin] HealthKit → sleep=\(String(describing: healthSummary.sleepHours))h steps=\(healthSummary.steps) rhr=\(String(describing: healthSummary.restingHeartRate)) hrv=\(String(describing: healthSummary.heartRateVariability))")
            } catch {
                print("[MindMargin] HealthKit fetch failed: \(error.localizedDescription)")
            }

            do {
                scheduleSummary = try await calendarClient.fetchTomorrowSummary()
                append(scheduleSummary)
                print("[MindMargin] Calendar → events=\(scheduleSummary.eventCount) busyHours=\(scheduleSummary.busyHours) b2b=\(scheduleSummary.backToBackCount) lateNight=\(scheduleSummary.lateNightEvents)")
            } catch {
                print("[MindMargin] Calendar fetch failed: \(error.localizedDescription)")
            }

            calendarEventsForAnalysis = (try? await calendarClient.fetchTomorrowEvents()) ?? []
        } else {
            print("[MindMargin] Skipping local fetch — permissions not ready")
        }

        let features = makeFeatures(from: healthSummary, schedule: scheduleSummary)
        if let localPrediction = try? await predictionService.predict(from: features) {
            prediction = localPrediction
            recommendations = recommendationService.recommendations(for: localPrediction, features: features)
        }
        dashboardFactors = Self.makeFallbackFactors(from: healthSummary, schedule: scheduleSummary)
        scheduleDisplayBlocks = Self.makeScheduleDisplayBlocks(
            from: calendarEventsForAnalysis,
            recommendations: recommendations
        )

        if let supabaseService {
            do {
                try await connectBackendIfNeeded()

                if supabaseService.isAuthenticated {
                    if isDemoModeEnabled || permissionsReady {
                        do {
                            try await supabaseService.syncHealthSummary(healthSummary)
                            print("[MindMargin] Health synced to Supabase")
                        } catch {
                            print("[MindMargin] Health sync failed: \(error.localizedDescription)")
                        }
                        do {
                            try await supabaseService.syncScheduleSummary(scheduleSummary)
                            print("[MindMargin] Schedule synced to Supabase")
                        } catch {
                            print("[MindMargin] Schedule sync failed: \(error.localizedDescription)")
                        }
                    }

                    let analysis = try await supabaseService.analyzeStress(
                        for: scheduleSummary.date,
                        calendarEvents: calendarEventsForAnalysis,
                        recommendationFeedback: makeRecommendationFeedbackPayloads()
                    )

                    prediction = analysis.prediction
                    if !analysis.recommendations.isEmpty {
                        recommendations = analysis.recommendations
                    }
                    scheduleDisplayBlocks = Self.makeScheduleDisplayBlocks(
                        from: calendarEventsForAnalysis,
                        recommendations: recommendations
                    )
                    if let fs = analysis.factorScores {
                        dashboardFactors = Self.makeDashboardFactors(
                            from: fs,
                            health: healthSummary,
                            schedule: scheduleSummary
                        )
                    }
                    let fetchedHealth = try await supabaseService.fetchHealthSummaries()
                    let fetchedSchedule = try await supabaseService.fetchScheduleSummaries()
                    let fetchedCheckIns = try await supabaseService.fetchCheckIns()
                    applyBackendSnapshot(
                        healthSummaries: fetchedHealth,
                        scheduleSummaries: fetchedSchedule,
                        checkIns: fetchedCheckIns
                    )
                    print("[MindMargin] Reloaded Supabase snapshot → healthRows=\(fetchedHealth.count) scheduleRows=\(fetchedSchedule.count) checkIns=\(fetchedCheckIns.count)")
                    backendStatus = .connected
                }
            } catch {
                backendStatus = .localOnly("Using \(isDemoModeEnabled ? "demo" : "local") prediction only because Supabase sync failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
        }

        ensureLocalHistoriesExist()
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
        backendStatus = .connecting
        do {
            try await supabaseService.signInAnonymouslyIfNeeded()
            hasAttemptedBackendSignIn = true
            backendStatus = .connected
        } catch {
            throw error
        }
    }

    private func refreshAuthorizationStates() async {
        healthAuthorizationState = await healthKitClient.authorizationState()
        calendarAuthorizationState = calendarClient.authorizationState()
        isHealthAuthorized = healthAuthorizationState == .authorized
        isCalendarAuthorized = calendarAuthorizationState == .authorized
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func syncProfilePreferences() async {
        guard let supabaseService else { return }

        do {
            try await connectBackendIfNeeded()
            guard supabaseService.isAuthenticated else { return }
            try await supabaseService.upsertProfile(
                reminderTime: reminderTime.formatted(date: .omitted, time: .shortened),
                preferredInterventionStyle: communicationStyle.rawValue,
                userName: accountName.isEmpty ? nil : accountName,
                email: accountEmail.isEmpty ? nil : accountEmail,
                password: accountPassword.isEmpty ? nil : accountPassword
            )
            backendStatus = .connected
        } catch {
            backendStatus = .localOnly("Preferences were updated locally. Supabase profile sync failed: \(error.localizedDescription)")
        }
    }

    private func applyBackendSnapshot(
        healthSummaries: [DailyHealthSummary],
        scheduleSummaries: [DailyScheduleSummary],
        checkIns: [StressCheckIn]
    ) {
        if !healthSummaries.isEmpty {
            healthHistory = healthSummaries
            if let latest = healthSummaries.last {
                healthSummary = latest
            }
        }

        if !scheduleSummaries.isEmpty {
            scheduleHistory = scheduleSummaries
            if let latest = scheduleSummaries.last {
                scheduleSummary = latest
            }
        }

        if !checkIns.isEmpty {
            checkInHistory = checkIns
        }
    }

    private func makeRecommendationFeedbackPayloads() -> [SupabaseService.RecommendationFeedbackPayload] {
        recommendations.compactMap { recommendation in
            guard let feedback = submittedRecommendationFeedbackByID[recommendation.id] else { return nil }
            return SupabaseService.RecommendationFeedbackPayload(
                recommendationID: recommendation.id,
                title: recommendation.title,
                category: recommendation.category,
                wasHelpful: feedback == .yes
            )
        }
    }

    private func makeFeatures(from health: DailyHealthSummary, schedule: DailyScheduleSummary) -> StressFeatures {
        let recentAverage = checkInHistory
            .suffix(5)
            .map(\.stressLevel)
            .average

        let sleepDebtHours = health.sleepHours.map { max(0, 7.8 - $0) } ?? 0
        let sleepRegularityScore = health.sleepHours.map { min(max($0 / 8.0, 0.35), 0.95) } ?? 0.5
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

    private static func makeDemoScenarioSnapshot(for scenario: DemoScenario) -> DemoScenarioSnapshot {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let targetDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
        }

        func health(offset: Int, sleep: Double, steps: Int, restingHR: Double, hrv: Double) -> DailyHealthSummary {
            DailyHealthSummary(
                id: UUID(),
                date: day(offset),
                sleepHours: sleep,
                steps: steps,
                restingHeartRate: restingHR,
                heartRateVariability: hrv
            )
        }

        func schedule(date: Date, eventCount: Int, busyHours: Double, backToBackCount: Int, lateNightEvents: Int) -> DailyScheduleSummary {
            DailyScheduleSummary(
                id: UUID(),
                date: date,
                eventCount: eventCount,
                busyHours: busyHours,
                backToBackCount: backToBackCount,
                lateNightEvents: lateNightEvents
            )
        }

        func checkIn(offset: Int, stressLevel: Int, energyLevel: Int, caffeineServings: Int, notes: String) -> StressCheckIn {
            StressCheckIn(
                id: UUID(),
                date: day(offset),
                stressLevel: stressLevel,
                energyLevel: energyLevel,
                caffeineServings: caffeineServings,
                helpfulYesterday: nil,
                notes: notes
            )
        }

        switch scenario {
        case .calmDay:
            let healthHistory = [
                health(offset: -4, sleep: 7.9, steps: 8200, restingHR: 62, hrv: 53),
                health(offset: -3, sleep: 8.2, steps: 9600, restingHR: 60, hrv: 55),
                health(offset: -2, sleep: 7.8, steps: 8700, restingHR: 61, hrv: 56),
                health(offset: -1, sleep: 8.0, steps: 9100, restingHR: 60, hrv: 58),
                health(offset: 0, sleep: 8.1, steps: 9800, restingHR: 59, hrv: 57),
            ]
            let scheduleHistory = [
                schedule(date: day(-4), eventCount: 2, busyHours: 2.0, backToBackCount: 0, lateNightEvents: 0),
                schedule(date: day(-3), eventCount: 3, busyHours: 2.5, backToBackCount: 0, lateNightEvents: 0),
                schedule(date: day(-2), eventCount: 2, busyHours: 1.5, backToBackCount: 0, lateNightEvents: 0),
                schedule(date: day(-1), eventCount: 3, busyHours: 3.0, backToBackCount: 1, lateNightEvents: 0),
                schedule(date: targetDate, eventCount: 2, busyHours: 2.5, backToBackCount: 0, lateNightEvents: 0),
            ]
            let events = [
                SupabaseService.CalendarEventPayload(title: "Design seminar", startTime: "10:00", endTime: "11:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Lunch with mentor", startTime: "14:00", endTime: "15:30", isBackToBack: false),
            ]
            return DemoScenarioSnapshot(
                healthSummary: healthHistory.last!,
                scheduleSummary: scheduleHistory.last!,
                calendarEvents: events,
                checkIns: [
                    checkIn(offset: -2, stressLevel: 2, energyLevel: 4, caffeineServings: 1, notes: "Pretty steady day."),
                    checkIn(offset: -1, stressLevel: 2, energyLevel: 4, caffeineServings: 1, notes: "Had room to reset."),
                    checkIn(offset: 0, stressLevel: 2, energyLevel: 5, caffeineServings: 1, notes: "Feeling rested."),
                ],
                healthHistory: healthHistory,
                scheduleHistory: scheduleHistory
            )

        case .packedDay:
            let healthHistory = [
                health(offset: -4, sleep: 7.0, steps: 6100, restingHR: 69, hrv: 44),
                health(offset: -3, sleep: 6.7, steps: 5200, restingHR: 70, hrv: 41),
                health(offset: -2, sleep: 6.5, steps: 4800, restingHR: 72, hrv: 39),
                health(offset: -1, sleep: 6.3, steps: 4500, restingHR: 74, hrv: 37),
                health(offset: 0, sleep: 6.1, steps: 4300, restingHR: 75, hrv: 35),
            ]
            let scheduleHistory = [
                schedule(date: day(-4), eventCount: 4, busyHours: 4.5, backToBackCount: 2, lateNightEvents: 0),
                schedule(date: day(-3), eventCount: 5, busyHours: 5.0, backToBackCount: 2, lateNightEvents: 0),
                schedule(date: day(-2), eventCount: 5, busyHours: 5.5, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: day(-1), eventCount: 6, busyHours: 6.0, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: targetDate, eventCount: 6, busyHours: 6.5, backToBackCount: 3, lateNightEvents: 1),
            ]
            let events = [
                SupabaseService.CalendarEventPayload(title: "Biochem lecture", startTime: "09:00", endTime: "10:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Study group", startTime: "10:05", endTime: "11:00", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Office hours", startTime: "11:10", endTime: "12:00", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Lab", startTime: "13:00", endTime: "14:30", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Project meeting", startTime: "15:00", endTime: "16:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Club event", startTime: "20:30", endTime: "21:30", isBackToBack: false),
            ]
            return DemoScenarioSnapshot(
                healthSummary: healthHistory.last!,
                scheduleSummary: scheduleHistory.last!,
                calendarEvents: events,
                checkIns: [
                    checkIn(offset: -2, stressLevel: 3, energyLevel: 3, caffeineServings: 2, notes: "A little overloaded."),
                    checkIn(offset: -1, stressLevel: 4, energyLevel: 2, caffeineServings: 2, notes: "Back-to-back classes were a lot."),
                    checkIn(offset: 0, stressLevel: 4, energyLevel: 2, caffeineServings: 3, notes: "Need better breaks tomorrow."),
                ],
                healthHistory: healthHistory,
                scheduleHistory: scheduleHistory
            )

        case .examWeek:
            let healthHistory = [
                health(offset: -4, sleep: 6.0, steps: 3500, restingHR: 77, hrv: 34),
                health(offset: -3, sleep: 5.8, steps: 3100, restingHR: 79, hrv: 31),
                health(offset: -2, sleep: 5.6, steps: 2800, restingHR: 80, hrv: 30),
                health(offset: -1, sleep: 5.4, steps: 2400, restingHR: 81, hrv: 29),
                health(offset: 0, sleep: 5.3, steps: 2200, restingHR: 82, hrv: 28),
            ]
            let scheduleHistory = [
                schedule(date: day(-4), eventCount: 5, busyHours: 6.0, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: day(-3), eventCount: 6, busyHours: 6.5, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: day(-2), eventCount: 6, busyHours: 7.0, backToBackCount: 4, lateNightEvents: 1),
                schedule(date: day(-1), eventCount: 7, busyHours: 7.5, backToBackCount: 4, lateNightEvents: 1),
                schedule(date: targetDate, eventCount: 7, busyHours: 8.0, backToBackCount: 4, lateNightEvents: 1),
            ]
            let events = [
                SupabaseService.CalendarEventPayload(title: "Morning review", startTime: "08:00", endTime: "09:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Exam prep session", startTime: "09:05", endTime: "10:30", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Statistics exam", startTime: "11:00", endTime: "13:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "TA meeting", startTime: "13:15", endTime: "14:00", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Lab write-up", startTime: "15:00", endTime: "17:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Group project", startTime: "18:00", endTime: "19:30", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Late study block", startTime: "21:00", endTime: "22:30", isBackToBack: false),
            ]
            return DemoScenarioSnapshot(
                healthSummary: healthHistory.last!,
                scheduleSummary: scheduleHistory.last!,
                calendarEvents: events,
                checkIns: [
                    checkIn(offset: -2, stressLevel: 4, energyLevel: 2, caffeineServings: 3, notes: "Sleep has been rough."),
                    checkIn(offset: -1, stressLevel: 5, energyLevel: 1, caffeineServings: 4, notes: "Exams are stacking up."),
                    checkIn(offset: 0, stressLevel: 5, energyLevel: 1, caffeineServings: 4, notes: "Need a real recovery plan."),
                ],
                healthHistory: healthHistory,
                scheduleHistory: scheduleHistory
            )
        }
    }

    private static func makeScheduleDisplayBlocks(
        from events: [SupabaseService.CalendarEventPayload],
        recommendations: [Recommendation]
    ) -> [ScheduleDisplayBlock] {
        guard !events.isEmpty else { return [] }

        let relaxationRecommendations = recommendations.filter {
            ["mindfulness", "movement", "general", "social"].contains($0.category)
        }

        var blocks: [ScheduleDisplayBlock] = []

        for (index, event) in events.enumerated() {
            blocks.append(
                ScheduleDisplayBlock(
                    kind: .event,
                    title: event.title,
                    subtitle: event.isBackToBack == true ? "Back-to-back commitment" : "Scheduled commitment",
                    startLabel: event.startTime,
                    endLabel: event.endTime,
                    tint: MindMarginTheme.yellow
                )
            )

            guard index < events.count - 1 else { continue }
            guard index < relaxationRecommendations.count else { continue }

            let recommendation = relaxationRecommendations[index]
            let nextEvent = events[index + 1]
            blocks.append(
                ScheduleDisplayBlock(
                    kind: .recommendation,
                    title: recommendation.title,
                    subtitle: recommendation.body,
                    startLabel: event.endTime,
                    endLabel: nextEvent.startTime,
                    tint: MindMarginTheme.green
                )
            )
        }

        return blocks
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
                value: factorScores.sleep?.rawHours.map { "\($0.formatted(.number.precision(.fractionLength(1))))h sleep" } ?? health.sleepHours.map { "\($0.formatted(.number.precision(.fractionLength(1))))h sleep" } ?? "Not available",
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
                value: {
                    guard let sleep = health.sleepHours else { return "Not available" }
                    return sleep >= 7.8 ? "None" : "\(max(0.1, 7.8 - sleep).formatted(.number.precision(.fractionLength(1))))h below baseline"
                }(),
                tint: MindMarginTheme.red,
                impact: health.sleepHours == nil ? .low : .high
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
                title: "Resting HR",
                value: health.restingHeartRate.map { "\(Int($0)) bpm" } ?? "Not available",
                tint: MindMarginTheme.orange,
                impact: health.restingHeartRate != nil ? .moderate : .low
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

        if let restingHR = health.restingHeartRate {
            return "\(Int(restingHR)) bpm"
        }

        return "Not available"
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

    private static func makeDemoScenarioSnapshot(for scenario: DemoScenario) -> DemoScenarioSnapshot {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let targetDate = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
        }

        func health(offset: Int, sleep: Double, steps: Int, restingHR: Double, hrv: Double) -> DailyHealthSummary {
            DailyHealthSummary(
                id: UUID(),
                date: day(offset),
                sleepHours: sleep,
                steps: steps,
                restingHeartRate: restingHR,
                heartRateVariability: hrv
            )
        }

        func schedule(date: Date, eventCount: Int, busyHours: Double, backToBackCount: Int, lateNightEvents: Int) -> DailyScheduleSummary {
            DailyScheduleSummary(
                id: UUID(),
                date: date,
                eventCount: eventCount,
                busyHours: busyHours,
                backToBackCount: backToBackCount,
                lateNightEvents: lateNightEvents
            )
        }

        func checkIn(offset: Int, stressLevel: Int, energyLevel: Int, caffeineServings: Int, notes: String) -> StressCheckIn {
            StressCheckIn(
                id: UUID(),
                date: day(offset),
                stressLevel: stressLevel,
                energyLevel: energyLevel,
                caffeineServings: caffeineServings,
                helpfulYesterday: nil,
                notes: notes
            )
        }

        switch scenario {
        case .calmDay:
            let healthHistory = [
                health(offset: -4, sleep: 7.9, steps: 8200, restingHR: 62, hrv: 53),
                health(offset: -3, sleep: 8.2, steps: 9600, restingHR: 60, hrv: 55),
                health(offset: -2, sleep: 7.8, steps: 8700, restingHR: 61, hrv: 56),
                health(offset: -1, sleep: 8.0, steps: 9100, restingHR: 60, hrv: 58),
                health(offset: 0, sleep: 8.1, steps: 9800, restingHR: 59, hrv: 57),
            ]
            let scheduleHistory = [
                schedule(date: day(-4), eventCount: 2, busyHours: 2.0, backToBackCount: 0, lateNightEvents: 0),
                schedule(date: day(-3), eventCount: 3, busyHours: 2.5, backToBackCount: 0, lateNightEvents: 0),
                schedule(date: day(-2), eventCount: 2, busyHours: 1.5, backToBackCount: 0, lateNightEvents: 0),
                schedule(date: day(-1), eventCount: 3, busyHours: 3.0, backToBackCount: 1, lateNightEvents: 0),
                schedule(date: targetDate, eventCount: 2, busyHours: 2.5, backToBackCount: 0, lateNightEvents: 0),
            ]
            let events = [
                SupabaseService.CalendarEventPayload(title: "Design seminar", startTime: "10:00", endTime: "11:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Lunch with mentor", startTime: "14:00", endTime: "15:30", isBackToBack: false),
            ]
            return DemoScenarioSnapshot(
                healthSummary: healthHistory.last!,
                scheduleSummary: scheduleHistory.last!,
                calendarEvents: events,
                checkIns: [
                    checkIn(offset: -2, stressLevel: 2, energyLevel: 4, caffeineServings: 1, notes: "Pretty steady day."),
                    checkIn(offset: -1, stressLevel: 2, energyLevel: 4, caffeineServings: 1, notes: "Had room to reset."),
                    checkIn(offset: 0, stressLevel: 2, energyLevel: 5, caffeineServings: 1, notes: "Feeling rested."),
                ],
                healthHistory: healthHistory,
                scheduleHistory: scheduleHistory
            )

        case .packedDay:
            let healthHistory = [
                health(offset: -4, sleep: 7.0, steps: 6100, restingHR: 69, hrv: 44),
                health(offset: -3, sleep: 6.7, steps: 5200, restingHR: 70, hrv: 41),
                health(offset: -2, sleep: 6.5, steps: 4800, restingHR: 72, hrv: 39),
                health(offset: -1, sleep: 6.3, steps: 4500, restingHR: 74, hrv: 37),
                health(offset: 0, sleep: 6.1, steps: 4300, restingHR: 75, hrv: 35),
            ]
            let scheduleHistory = [
                schedule(date: day(-4), eventCount: 4, busyHours: 4.5, backToBackCount: 2, lateNightEvents: 0),
                schedule(date: day(-3), eventCount: 5, busyHours: 5.0, backToBackCount: 2, lateNightEvents: 0),
                schedule(date: day(-2), eventCount: 5, busyHours: 5.5, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: day(-1), eventCount: 6, busyHours: 6.0, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: targetDate, eventCount: 6, busyHours: 6.5, backToBackCount: 3, lateNightEvents: 1),
            ]
            let events = [
                SupabaseService.CalendarEventPayload(title: "Biochem lecture", startTime: "09:00", endTime: "10:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Study group", startTime: "10:05", endTime: "11:00", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Office hours", startTime: "11:10", endTime: "12:00", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Lab", startTime: "13:00", endTime: "14:30", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Project meeting", startTime: "15:00", endTime: "16:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Club event", startTime: "20:30", endTime: "21:30", isBackToBack: false),
            ]
            return DemoScenarioSnapshot(
                healthSummary: healthHistory.last!,
                scheduleSummary: scheduleHistory.last!,
                calendarEvents: events,
                checkIns: [
                    checkIn(offset: -2, stressLevel: 3, energyLevel: 3, caffeineServings: 2, notes: "A little overloaded."),
                    checkIn(offset: -1, stressLevel: 4, energyLevel: 2, caffeineServings: 2, notes: "Back-to-back classes were a lot."),
                    checkIn(offset: 0, stressLevel: 4, energyLevel: 2, caffeineServings: 3, notes: "Need better breaks tomorrow."),
                ],
                healthHistory: healthHistory,
                scheduleHistory: scheduleHistory
            )

        case .examWeek:
            let healthHistory = [
                health(offset: -4, sleep: 6.0, steps: 3500, restingHR: 77, hrv: 34),
                health(offset: -3, sleep: 5.8, steps: 3100, restingHR: 79, hrv: 31),
                health(offset: -2, sleep: 5.6, steps: 2800, restingHR: 80, hrv: 30),
                health(offset: -1, sleep: 5.4, steps: 2400, restingHR: 81, hrv: 29),
                health(offset: 0, sleep: 5.3, steps: 2200, restingHR: 82, hrv: 28),
            ]
            let scheduleHistory = [
                schedule(date: day(-4), eventCount: 5, busyHours: 6.0, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: day(-3), eventCount: 6, busyHours: 6.5, backToBackCount: 3, lateNightEvents: 1),
                schedule(date: day(-2), eventCount: 6, busyHours: 7.0, backToBackCount: 4, lateNightEvents: 1),
                schedule(date: day(-1), eventCount: 7, busyHours: 7.5, backToBackCount: 4, lateNightEvents: 1),
                schedule(date: targetDate, eventCount: 7, busyHours: 8.0, backToBackCount: 4, lateNightEvents: 1),
            ]
            let events = [
                SupabaseService.CalendarEventPayload(title: "Morning review", startTime: "08:00", endTime: "09:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Exam prep session", startTime: "09:05", endTime: "10:30", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Statistics exam", startTime: "11:00", endTime: "13:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "TA meeting", startTime: "13:15", endTime: "14:00", isBackToBack: true),
                SupabaseService.CalendarEventPayload(title: "Lab write-up", startTime: "15:00", endTime: "17:00", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Group project", startTime: "18:00", endTime: "19:30", isBackToBack: false),
                SupabaseService.CalendarEventPayload(title: "Late study block", startTime: "21:00", endTime: "22:30", isBackToBack: false),
            ]
            return DemoScenarioSnapshot(
                healthSummary: healthHistory.last!,
                scheduleSummary: scheduleHistory.last!,
                calendarEvents: events,
                checkIns: [
                    checkIn(offset: -2, stressLevel: 4, energyLevel: 2, caffeineServings: 3, notes: "Sleep has been rough."),
                    checkIn(offset: -1, stressLevel: 5, energyLevel: 1, caffeineServings: 4, notes: "Exams are stacking up."),
                    checkIn(offset: 0, stressLevel: 5, energyLevel: 1, caffeineServings: 4, notes: "Need a real recovery plan."),
                ],
                healthHistory: healthHistory,
                scheduleHistory: scheduleHistory
            )
        }
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
