import Foundation

final class SupabaseService {
    let configuration: SupabaseConfiguration

    // Set both after the user signs in.
    var sessionToken: String?
    var userId: String?

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
    }

    func signInAnonymouslyIfNeeded() async throws {
        // Replace with Supabase client auth flow after adding the package in Xcode.
    }

    func syncHealthSummary(_ summary: DailyHealthSummary) async throws {
        guard let token = sessionToken, let uid = userId else {
            throw SupabaseServiceError.notAuthenticated
        }

        struct Payload: Encodable {
            let userId: String
            let summaryDate: String
            let sleepHours: Double
            let steps: Int
            let restingHeartRate: Double?
            let heartRateVariability: Double?
        }

        let payload = Payload(
            userId: uid,
            summaryDate: dateString(from: summary.date),
            sleepHours: summary.sleepHours,
            steps: summary.steps,
            restingHeartRate: summary.restingHeartRate,
            heartRateVariability: summary.heartRateVariability
        )

        try await upsert(table: "daily_health_summaries", payload: payload, token: token)
    }

    func syncScheduleSummary(_ summary: DailyScheduleSummary) async throws {
        guard let token = sessionToken, let uid = userId else {
            throw SupabaseServiceError.notAuthenticated
        }

        struct Payload: Encodable {
            let userId: String
            let summaryDate: String
            let eventCount: Int
            let busyHours: Double
            let backToBackCount: Int
            let lateNightEvents: Int
        }

        let payload = Payload(
            userId: uid,
            summaryDate: dateString(from: summary.date),
            eventCount: summary.eventCount,
            busyHours: summary.busyHours,
            backToBackCount: summary.backToBackCount,
            lateNightEvents: summary.lateNightEvents
        )

        try await upsert(table: "daily_schedule_summaries", payload: payload, token: token)
    }

    func syncCheckIn(_ checkIn: StressCheckIn) async throws {
        guard let token = sessionToken, let uid = userId else {
            throw SupabaseServiceError.notAuthenticated
        }

        struct Payload: Encodable {
            let userId: String
            let checkInDate: String
            let stressLevel: Int
            let energyLevel: Int
            let caffeineServings: Int
            let notes: String?
        }

        let payload = Payload(
            userId: uid,
            checkInDate: dateString(from: checkIn.date),
            stressLevel: checkIn.stressLevel,
            energyLevel: checkIn.energyLevel,
            caffeineServings: checkIn.caffeineServings,
            notes: checkIn.notes
        )

        let url = configuration.url.appendingPathComponent("rest/v1/stress_check_ins")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "unknown")
        }
    }

    func fetchRecommendations(for date: Date) async throws -> [Recommendation] {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        var components = URLComponents(
            url: configuration.url.appendingPathComponent("rest/v1/recommendations"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "target_date", value: "eq.\(dateString(from: date))"),
            URLQueryItem(name: "select", value: "id,title,body,rationale,category"),
            URLQueryItem(name: "order", value: "created_at.asc"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "unknown")
        }

        let rows = try JSONDecoder().decode([RecommendationRow].self, from: data)
        return rows.map { Recommendation(id: $0.id, title: $0.title, body: $0.body,
                                         rationale: $0.rationale, category: $0.category) }
    }

    // MARK: - Helpers

    private func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func upsert<T: Encodable>(table: String, payload: T, token: String) async throws {
        let url = configuration.url.appendingPathComponent("rest/v1/\(table)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "unknown")
        }
    }

    // MARK: - analyze-stress edge function

    /// Calls the `analyze-stress` edge function to compute a stress score,
    /// generate GPT-backed recommendations, and persist both to Supabase.
    ///
    /// - Parameters:
    ///   - date: The date to analyse (typically today or tomorrow).
    ///   - calendarEvents: Optional EventKit events for the date; when provided
    ///     the edge function feeds them directly into the GPT prompt so
    ///     suggestions reference real meeting titles and times.
    /// - Returns: A `StressPrediction` and the list of AI-generated `Recommendation`s.
    @discardableResult
    func analyzeStress(
        for date: Date,
        calendarEvents: [CalendarEventPayload] = []
    ) async throws -> (prediction: StressPrediction, recommendations: [Recommendation]) {
        guard let token = sessionToken else {
            throw SupabaseServiceError.notAuthenticated
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let targetDate = formatter.string(from: date)

        let payload = AnalyzeStressRequest(
            targetDate: targetDate,
            calendarEvents: calendarEvents.isEmpty ? nil : calendarEvents
        )

        let url = configuration.url.appendingPathComponent("functions/v1/analyze-stress")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseServiceError.edgeFunctionFailed(body)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(AnalyzeStressResponse.self, from: data)

        // Map risk level string to enum
        let riskLevel: StressPrediction.RiskLevel
        switch result.riskLevel {
        case "high":   riskLevel = .high
        case "medium": riskLevel = .medium
        default:       riskLevel = .low
        }

        // Normalise 0–10 score to 0–1 for the existing StressScoreCard display
        let prediction = StressPrediction(
            riskLevel: riskLevel,
            score: result.stressScore / 10.0,
            topFactors: result.topFactors
        )

        let recommendations = result.recommendations.map {
            Recommendation(id: $0.id, title: $0.title, body: $0.body,
                           rationale: $0.rationale, category: $0.category)
        }

        return (prediction, recommendations)
    }
}

enum SupabaseServiceError: LocalizedError {
    case notAuthenticated
    case edgeFunctionFailed(String)
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No active session. Sign in before making requests."
        case .edgeFunctionFailed(let body):
            return "Edge function returned an error: \(body)"
        case .requestFailed(let body):
            return "Request failed: \(body)"
        }
    }
}
