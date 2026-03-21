import Foundation

protocol StressPredicting {
    func predict(from features: StressFeatures) async throws -> StressPrediction
}
