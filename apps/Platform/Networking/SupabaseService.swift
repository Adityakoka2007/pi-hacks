import Foundation

final class SupabaseService {
    let configuration: SupabaseConfiguration

    // Set this after the user signs in so edge function calls are authenticated.
    var sessionToken: String?

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
    }

    func signInAnonymouslyIfNeeded() async throws {
        // Replace with Supabase client auth flow after adding the package in Xcode.
    }

    func syncHealthSummary(_ summary: DailyHealthSummary) async throws {
        // Upsert into daily_health_summaries.
    }

    func syncScheduleSummary(_ summary: DailyScheduleSummary) async throws {
        // Upsert into daily_schedule_summaries.
    }

    func syncCheckIn(_ checkIn: StressCheckIn) async throws {
        // Insert into stress_check_ins.
    }

    func fetchRecommendations(for date: Date) async throws -> [Recommendation] {
        // Query recommendations for the given date.
        return Recommendation.sampleData
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

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No active session. Sign in before calling analyzeStress."
        case .edgeFunctionFailed(let body):
            return "Edge function returned an error: \(body)"
        }
    }
}
