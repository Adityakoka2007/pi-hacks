import Foundation

struct StressCheckIn: Codable, Identifiable {
    let id: UUID
    let date: Date
    let stressLevel: Int
    let energyLevel: Int
    let caffeineServings: Int
    let notes: String?
}
