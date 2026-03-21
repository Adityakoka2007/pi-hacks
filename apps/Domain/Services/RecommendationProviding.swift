import Foundation

protocol RecommendationProviding {
    func recommendations(for prediction: StressPrediction, features: StressFeatures) -> [Recommendation]
}
