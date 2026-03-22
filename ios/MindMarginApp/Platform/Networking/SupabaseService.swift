import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

final class SupabaseService {
    struct Session: Decodable {
        let accessToken: String
        let refreshToken: String?
        let user: User

        struct User: Decodable {
            let id: String
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }

    struct FactorScores: Decodable {
        let sleep: SleepFactor?
        let hrv: HrvFactor?
        let activity: ActivityFactor?
        let restingHR: RestingHRFactor?
        let schedule: ScheduleFactor?
        let checkIn: CheckInFactor?

        struct SleepFactor: Decodable {
            let rawHours: Double?
            let score: Double

            enum CodingKeys: String, CodingKey {
                case rawHours = "raw_hours"
                case score
            }
        }

        struct HrvFactor: Decodable {
            let rawMilliseconds: Double?
            let score: Double
            let available: Bool?

            enum CodingKeys: String, CodingKey {
                case rawMilliseconds = "raw_ms"
                case score
                case available
            }
        }

        struct ActivityFactor: Decodable {
            let rawSteps: Int?
            let score: Double

            enum CodingKeys: String, CodingKey {
                case rawSteps = "raw_steps"
                case score
            }
        }

        struct RestingHRFactor: Decodable {
            let rawBPM: Double?
            let score: Double
            let available: Bool?

            enum CodingKeys: String, CodingKey {
                case rawBPM = "raw_bpm"
                case score
                case available
            }
        }

        struct ScheduleFactor: Decodable {
            let score: Double
            let busyHours: Double?
            let backToBack: Int?
            let lateNight: Int?

            enum CodingKeys: String, CodingKey {
                case score
                case busyHours = "busy_hours"
                case backToBack = "back_to_back"
                case lateNight = "late_night"
            }
        }

        struct CheckInFactor: Decodable {
            let score: Double
            let averageStress: Double?
            let available: Bool?

            enum CodingKeys: String, CodingKey {
                case score
                case averageStress = "avg_stress"
                case available
            }
        }

        enum CodingKeys: String, CodingKey {
            case sleep
            case hrv
            case activity
            case restingHR = "resting_hr"
            case schedule
            case checkIn = "check_in"
        }
    }

    struct AnalysisResult: Decodable {
        let stressScore: Double
        let riskLevel: String
        let factorScores: FactorScores?
        let topFactors: [String]
        let recommendations: [RecommendationRow]

        enum CodingKeys: String, CodingKey {
            case stressScore = "stress_score"
            case riskLevel = "risk_level"
            case factorScores = "factor_scores"
            case topFactors = "top_factors"
            case recommendations
        }
    }

    struct CalendarEventPayload: Encodable {
        let title: String
        let startTime: String
        let endTime: String
        let isBackToBack: Bool?

        enum CodingKeys: String, CodingKey {
            case title
            case startTime = "start_time"
            case endTime = "end_time"
            case isBackToBack = "is_back_to_back"
        }
    }

    private struct HealthSummaryPayload: Encodable {
        let summaryDate: String
        let sleepHours: Double
        let steps: Int
        let restingHeartRate: Double?
        let heartRateVariability: Double?

        enum CodingKeys: String, CodingKey {
            case summaryDate = "summary_date"
            case sleepHours = "sleep_hours"
            case steps
            case restingHeartRate = "resting_heart_rate"
            case heartRateVariability = "heart_rate_variability"
        }
    }

    private struct ScheduleSummaryPayload: Encodable {
        let summaryDate: String
        let eventCount: Int
        let busyHours: Double
        let backToBackCount: Int
        let lateNightEvents: Int

        enum CodingKeys: String, CodingKey {
            case summaryDate = "summary_date"
            case eventCount = "event_count"
            case busyHours = "busy_hours"
            case backToBackCount = "back_to_back_count"
            case lateNightEvents = "late_night_events"
        }
    }

    private struct CheckInPayload: Encodable {
        let checkInDate: String
        let stressLevel: Int
        let energyLevel: Int
        let caffeineServings: Int
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case checkInDate = "check_in_date"
            case stressLevel = "stress_level"
            case energyLevel = "energy_level"
            case caffeineServings = "caffeine_servings"
            case notes
        }
    }

    private struct AnalyzeStressPayload: Encodable {
        let targetDate: String
        let calendarEvents: [CalendarEventPayload]?

        enum CodingKeys: String, CodingKey {
            case targetDate = "target_date"
            case calendarEvents = "calendar_events"
        }
    }

    private struct ProfilePayload: Encodable {
        let id: String
        let checkInTime: String
        let preferredInterventionStyle: String
        let userName: String?
        let email: String?
        let password: String?

        enum CodingKeys: String, CodingKey {
            case id
            case checkInTime = "check_in_time"
            case preferredInterventionStyle = "preferred_intervention_style"
            case userName = "user_name"
            case email
            case password
        }
    }

    private struct HealthSummaryRow: Decodable {
        let id: UUID
        let summaryDate: String
        let sleepHours: Double
        let steps: Int
        let restingHeartRate: Double?
        let heartRateVariability: Double?

        enum CodingKeys: String, CodingKey {
            case id
            case summaryDate = "summary_date"
            case sleepHours = "sleep_hours"
            case steps
            case restingHeartRate = "resting_heart_rate"
            case heartRateVariability = "heart_rate_variability"
        }
    }

    private struct ScheduleSummaryRow: Decodable {
        let id: UUID
        let summaryDate: String
        let eventCount: Int
        let busyHours: Double
        let backToBackCount: Int
        let lateNightEvents: Int

        enum CodingKeys: String, CodingKey {
            case id
            case summaryDate = "summary_date"
            case eventCount = "event_count"
            case busyHours = "busy_hours"
            case backToBackCount = "back_to_back_count"
            case lateNightEvents = "late_night_events"
        }
    }

    private struct CheckInRow: Decodable {
        let id: UUID
        let checkInDate: String
        let stressLevel: Int
        let energyLevel: Int
        let caffeineServings: Int
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case id
            case checkInDate = "check_in_date"
            case stressLevel = "stress_level"
            case energyLevel = "energy_level"
            case caffeineServings = "caffeine_servings"
            case notes
        }
    }

    struct RecommendationRow: Decodable {
        let id: UUID
        let title: String
        let body: String
        let rationale: String
        let category: String
    }

    let configuration: SupabaseConfiguration
    private let session: URLSession

    private(set) var sessionToken: String?
    private(set) var userId: String?

    private static let refreshTokenStorageKey = "MindMargin.Supabase.refreshToken"

    init(configuration: SupabaseConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    var isConfigured: Bool { true }
    var isAuthenticated: Bool { sessionToken != nil && userId != nil }

    func signInAnonymouslyIfNeeded() async throws {
        guard !isAuthenticated else { return }

        let url = configuration.url.appendingPathComponent("auth/v1/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let authSession = try await send(request, decode: Session.self, acceptedStatusCodes: [200, 201])
        applySession(authSession)
    }

    /// Reloads access token from stored refresh token (OAuth or anonymous).
    func restoreSessionIfNeeded() async {
        guard !isAuthenticated else { return }
        guard let refresh = UserDefaults.standard.string(forKey: Self.refreshTokenStorageKey), !refresh.isEmpty else { return }
        do {
            try await refreshAccessToken(using: refresh)
        } catch {
            signOut()
        }
    }

    func signOut() {
        sessionToken = nil
        userId = nil
        UserDefaults.standard.removeObject(forKey: Self.refreshTokenStorageKey)
    }

    func signUp(email: String, password: String) async throws {
        let url = configuration.url.appendingPathComponent("auth/v1/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EmailAuthBody(email: email, password: password))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseServiceError.invalidResponse
        }
        guard [200, 201].contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseServiceError.requestFailed(body)
        }

        try await signIn(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        var components = URLComponents(url: configuration.url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EmailAuthBody(email: email, password: password))

        let authSession = try await send(request, decode: Session.self, acceptedStatusCodes: [200, 201])
        applySession(authSession)
    }

    /// Native Sign in with Apple → Supabase `grant_type=id_token`.
    func signInWithApple(idToken: String, rawNonce: String?) async throws {
        var components = URLComponents(url: configuration.url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            IdTokenGrantBody(provider: "apple", idToken: idToken, nonce: rawNonce)
        )

        let authSession = try await send(request, decode: Session.self, acceptedStatusCodes: [200, 201])
        applySession(authSession)
    }

    /// Google OAuth via PKCE + system browser sheet (enable Google in Supabase; add redirect URL there).
    @MainActor
    func signInWithGoogle() async throws {
        let redirect = configuration.oauthRedirectURL
        guard let scheme = URL(string: redirect)?.scheme, !scheme.isEmpty else {
            throw SupabaseServiceError.requestFailed("Invalid oauth redirect URL")
        }

        let verifier = Self.makePKCEVerifier()
        let challenge = Self.makePKCEChallenge(from: verifier)

        var components = URLComponents(url: configuration.url.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirect),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components.url else {
            throw SupabaseServiceError.invalidResponse
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let webSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: SupabaseServiceError.invalidResponse)
                    return
                }
                continuation.resume(returning: url)
            }
            webSession.presentationContextProvider = OAuthPresentationAnchor.shared
            webSession.prefersEphemeralWebBrowserSession = false
            if !webSession.start() {
                continuation.resume(throwing: SupabaseServiceError.requestFailed("Could not start sign-in session"))
            }
        }

        guard
            let parsed = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let code = parsed.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw SupabaseServiceError.requestFailed("OAuth callback missing authorization code")
        }

        try await exchangePKCE(code: code, codeVerifier: verifier)
    }

    private func applySession(_ authSession: Session) {
        sessionToken = authSession.accessToken
        userId = authSession.user.id
        if let refresh = authSession.refreshToken {
            UserDefaults.standard.set(refresh, forKey: Self.refreshTokenStorageKey)
        }
    }

    private func refreshAccessToken(using refreshToken: String) async throws {
        var components = URLComponents(url: configuration.url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshTokenBody(refreshToken: refreshToken))

        let authSession = try await send(request, decode: Session.self, acceptedStatusCodes: [200, 201])
        applySession(authSession)
    }

    private func exchangePKCE(code: String, codeVerifier: String) async throws {
        var components = URLComponents(url: configuration.url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "pkce")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(PKCEExchangeBody(authCode: code, codeVerifier: codeVerifier))

        let authSession = try await send(request, decode: Session.self, acceptedStatusCodes: [200, 201])
        applySession(authSession)
    }

    private static func makePKCEVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func makePKCEChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private struct IdTokenGrantBody: Encodable {
        let provider: String
        let idToken: String
        let nonce: String?

        enum CodingKeys: String, CodingKey {
            case provider
            case idToken = "id_token"
            case nonce
        }
    }

    private struct RefreshTokenBody: Encodable {
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    private struct EmailAuthBody: Encodable {
        let email: String
        let password: String
    }

    private struct PKCEExchangeBody: Encodable {
        let authCode: String
        let codeVerifier: String

        enum CodingKeys: String, CodingKey {
            case authCode = "auth_code"
            case codeVerifier = "code_verifier"
        }
    }

    func upsertProfile(
        reminderTime: String,
        preferredInterventionStyle: String,
        userName: String? = nil,
        email: String? = nil,
        password: String? = nil
    ) async throws {
        guard let token = sessionToken, let userId else {
            throw SupabaseServiceError.notAuthenticated
        }

        let payload = ProfilePayload(
            id: userId,
            checkInTime: reminderTime,
            preferredInterventionStyle: preferredInterventionStyle.lowercased(),
            userName: userName,
            email: email,
            password: password
        )

        try await upsert(table: "profiles", payload: payload, token: token, conflictColumns: "id")
    }

    func syncHealthSummary(_ summary: DailyHealthSummary) async throws {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let payload = HealthSummaryPayload(
            summaryDate: Self.dayFormatter.string(from: summary.date),
            sleepHours: summary.sleepHours,
            steps: summary.steps,
            restingHeartRate: summary.restingHeartRate,
            heartRateVariability: summary.heartRateVariability
        )

        try await invokeFunction(named: "upsert-health", payload: payload, token: token)
    }

    func syncScheduleSummary(_ summary: DailyScheduleSummary) async throws {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let payload = ScheduleSummaryPayload(
            summaryDate: Self.dayFormatter.string(from: summary.date),
            eventCount: summary.eventCount,
            busyHours: summary.busyHours,
            backToBackCount: summary.backToBackCount,
            lateNightEvents: summary.lateNightEvents
        )

        try await invokeFunction(named: "upsert-schedule", payload: payload, token: token)
    }

    func syncCheckIn(_ checkIn: StressCheckIn) async throws {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let payload = CheckInPayload(
            checkInDate: Self.dayFormatter.string(from: checkIn.date),
            stressLevel: checkIn.stressLevel,
            energyLevel: checkIn.energyLevel,
            caffeineServings: checkIn.caffeineServings,
            notes: checkIn.notes
        )

        try await invokeFunction(named: "upsert-check-in", payload: payload, token: token)
    }

    func analyzeStress(
        for date: Date,
        calendarEvents: [CalendarEventPayload] = []
    ) async throws -> (prediction: StressPrediction, recommendations: [Recommendation], factorScores: FactorScores?) {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let payload = AnalyzeStressPayload(
            targetDate: Self.dayFormatter.string(from: date),
            calendarEvents: calendarEvents.isEmpty ? nil : calendarEvents
        )

        let result = try await invokeFunction(
            named: "analyze-stress",
            payload: payload,
            token: token,
            decode: AnalysisResult.self
        )

        let riskLevel: StressPrediction.RiskLevel
        switch result.riskLevel {
        case "high":
            riskLevel = .high
        case "medium":
            riskLevel = .medium
        default:
            riskLevel = .low
        }

        let prediction = StressPrediction(
            riskLevel: riskLevel,
            score: result.stressScore / 10.0,
            topFactors: result.topFactors
        )
        let recommendations = result.recommendations.map {
            Recommendation(id: $0.id, title: $0.title, body: $0.body, rationale: $0.rationale, category: $0.category)
        }

        return (prediction, recommendations, result.factorScores)
    }

    func fetchCheckIns(limit: Int = 30) async throws -> [StressCheckIn] {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        var components = URLComponents(url: configuration.url.appendingPathComponent("rest/v1/stress_check_ins"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,check_in_date,stress_level,energy_level,caffeine_servings,notes"),
            URLQueryItem(name: "order", value: "check_in_date.desc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        var request = makeAuthorizedRequest(url: components.url!, token: token)
        request.httpMethod = "GET"

        let rows = try await send(request, decode: [CheckInRow].self)
        return rows
            .compactMap { row in
                guard let date = Self.dayFormatter.date(from: row.checkInDate) else { return nil }
                return StressCheckIn(
                    id: row.id,
                    date: date,
                    stressLevel: row.stressLevel,
                    energyLevel: row.energyLevel,
                    caffeineServings: row.caffeineServings,
                    helpfulYesterday: nil,
                    notes: row.notes
                )
            }
            .sorted { $0.date < $1.date }
    }

    func fetchHealthSummaries(days: Int = 7) async throws -> [DailyHealthSummary] {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -(max(days - 1, 0)), to: .now) ?? .now
        var components = URLComponents(url: configuration.url.appendingPathComponent("rest/v1/daily_health_summaries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,summary_date,sleep_hours,steps,resting_heart_rate,heart_rate_variability"),
            URLQueryItem(name: "summary_date", value: "gte.\(Self.dayFormatter.string(from: startDate))"),
            URLQueryItem(name: "order", value: "summary_date.asc"),
        ]

        var request = makeAuthorizedRequest(url: components.url!, token: token)
        request.httpMethod = "GET"

        let rows = try await send(request, decode: [HealthSummaryRow].self)
        return rows.compactMap { row in
            guard let date = Self.dayFormatter.date(from: row.summaryDate) else { return nil }
            return DailyHealthSummary(
                id: row.id,
                date: date,
                sleepHours: row.sleepHours,
                steps: row.steps,
                restingHeartRate: row.restingHeartRate,
                heartRateVariability: row.heartRateVariability
            )
        }
    }

    func fetchScheduleSummaries(days: Int = 7) async throws -> [DailyScheduleSummary] {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let startDate = Calendar.current.date(byAdding: .day, value: -(max(days - 1, 0)), to: .now) ?? .now
        var components = URLComponents(url: configuration.url.appendingPathComponent("rest/v1/daily_schedule_summaries"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,summary_date,event_count,busy_hours,back_to_back_count,late_night_events"),
            URLQueryItem(name: "summary_date", value: "gte.\(Self.dayFormatter.string(from: startDate))"),
            URLQueryItem(name: "order", value: "summary_date.asc"),
        ]

        var request = makeAuthorizedRequest(url: components.url!, token: token)
        request.httpMethod = "GET"

        let rows = try await send(request, decode: [ScheduleSummaryRow].self)
        return rows.compactMap { row in
            guard let date = Self.dayFormatter.date(from: row.summaryDate) else { return nil }
            return DailyScheduleSummary(
                id: row.id,
                date: date,
                eventCount: row.eventCount,
                busyHours: row.busyHours,
                backToBackCount: row.backToBackCount,
                lateNightEvents: row.lateNightEvents
            )
        }
    }

    private func invokeFunction<T: Encodable>(named name: String, payload: T, token: String) async throws {
        _ = try await invokeFunction(named: name, payload: payload, token: token, decode: EmptyResponse.self)
    }

    private func invokeFunction<T: Encodable, U: Decodable>(
        named name: String,
        payload: T,
        token: String,
        decode: U.Type
    ) async throws -> U {
        let url = configuration.url.appendingPathComponent("functions/v1/\(name)")
        var request = makeAuthorizedRequest(url: url, token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        return try await send(request, decode: decode)
    }

    private func upsert<T: Encodable>(table: String, payload: T, token: String, conflictColumns: String) async throws {
        var components = URLComponents(url: configuration.url.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "on_conflict", value: conflictColumns),
        ]

        var request = makeAuthorizedRequest(url: components.url!, token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(payload)

        _ = try await send(request, decode: EmptyResponse.self, acceptedStatusCodes: [200, 201, 204])
    }

    private func makeAuthorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        return request
    }

    private func send<T: Decodable>(
        _ request: URLRequest,
        decode: T.Type,
        acceptedStatusCodes: Set<Int> = [200, 201]
    ) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseServiceError.invalidResponse
        }

        guard acceptedStatusCodes.contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseServiceError.requestFailed(body)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SupabaseServiceError.decodingFailed(error.localizedDescription)
        }
    }

    private struct EmptyResponse: Decodable {}

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private final class OAuthPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthPresentationAnchor()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return window
        }
        if let window = scenes.flatMap(\.windows).first {
            return window
        }
        if let scene = scenes.first {
            return ASPresentationAnchor(windowScene: scene)
        }
        fatalError("No UIWindowScene available for OAuth")
    }
}

enum SupabaseServiceError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case decodingFailed(String)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No active Supabase session is available."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .decodingFailed(let message):
            return "Supabase response decoding failed: \(message)"
        case .requestFailed(let body):
            return "Supabase request failed: \(body)"
        }
    }
}
