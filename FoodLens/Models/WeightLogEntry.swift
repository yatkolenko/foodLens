import Foundation

struct WeightLogEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    var weightKg: Double
}
