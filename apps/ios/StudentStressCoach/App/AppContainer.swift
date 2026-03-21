import Combine
import Foundation

final class AppContainer: ObservableObject {
    let healthKitClient: HealthKitClient
    let calendarClient: CalendarClient
    let predictionService: any StressPredicting
    let recommendationService: any RecommendationProviding
    let supabaseService: SupabaseService

    init() {
        self.healthKitClient = HealthKitClient()
        self.calendarClient = CalendarClient()
        self.predictionService = RuleBasedStressPredictor()
        self.recommendationService = RecommendationEngine()
        self.supabaseService = SupabaseService(configuration: .placeholder)
    }
}
