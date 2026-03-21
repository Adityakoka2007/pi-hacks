import Foundation

struct StressFeatures: Codable {
    let sleepDebtHours: Double
    let sleepRegularityScore: Double
    let activityTrendScore: Double
    let scheduleIntensityScore: Double
    let recentStressAverage: Double
}
