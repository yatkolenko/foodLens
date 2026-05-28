import Foundation

struct DailyNutritionAdvice: Codable, Identifiable, Hashable {
    var id: String { dayKey }
    var dayKey: String
    var generatedAt: Date
    var summary: String
    var positives: [String]
    var improvements: [String]
    var nextStep: String
}
