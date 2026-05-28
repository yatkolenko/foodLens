import Foundation

struct FoodEntry: Codable, Identifiable, Hashable {
    struct Analysis: Codable, Hashable {
        struct ItemBreakdown: Codable, Hashable, Identifiable {
            var name: String
            var quantityDescription: String
            var mealType: MealType?
            var estimatedWeightGrams: Double?
            var caloriesKcal: Double
            var proteinG: Double
            var carbsG: Double
            var fatG: Double

            var id: String {
                "\(name)|\(quantityDescription)|\(mealType?.rawValue ?? "")|\(estimatedWeightGrams ?? 0)|\(caloriesKcal)|\(proteinG)|\(carbsG)|\(fatG)"
            }

            enum CodingKeys: String, CodingKey {
                case name, quantityDescription, mealType, estimatedWeightGrams, caloriesKcal, proteinG, carbsG, fatG
            }

            init(
                name: String,
                quantityDescription: String,
                mealType: MealType? = nil,
                estimatedWeightGrams: Double? = nil,
                caloriesKcal: Double,
                proteinG: Double,
                carbsG: Double = 0,
                fatG: Double = 0
            ) {
                self.name = name
                self.quantityDescription = quantityDescription
                self.mealType = mealType
                self.estimatedWeightGrams = estimatedWeightGrams
                self.caloriesKcal = caloriesKcal
                self.proteinG = proteinG
                self.carbsG = carbsG
                self.fatG = fatG
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                name = try c.decode(String.self, forKey: .name)
                quantityDescription = try c.decode(String.self, forKey: .quantityDescription)
                mealType = try c.decodeIfPresent(MealType.self, forKey: .mealType)
                estimatedWeightGrams = try c.decodeIfPresent(Double.self, forKey: .estimatedWeightGrams)
                caloriesKcal = try c.decode(Double.self, forKey: .caloriesKcal)
                proteinG = try c.decode(Double.self, forKey: .proteinG)
                carbsG = try c.decodeIfPresent(Double.self, forKey: .carbsG) ?? 0
                fatG = try c.decodeIfPresent(Double.self, forKey: .fatG) ?? 0
            }

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(name, forKey: .name)
                try c.encode(quantityDescription, forKey: .quantityDescription)
                try c.encodeIfPresent(mealType, forKey: .mealType)
                try c.encodeIfPresent(estimatedWeightGrams, forKey: .estimatedWeightGrams)
                try c.encode(caloriesKcal, forKey: .caloriesKcal)
                try c.encode(proteinG, forKey: .proteinG)
                try c.encode(carbsG, forKey: .carbsG)
                try c.encode(fatG, forKey: .fatG)
            }
        }

        var foodName: String
        var caloriesKcal: Double
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var confidence: Double?
        var assumptions: String?
        var items: [ItemBreakdown]

        enum CodingKeys: String, CodingKey {
            case foodName, caloriesKcal, proteinG, carbsG, fatG, confidence, assumptions, items
        }

        init(
            foodName: String,
            caloriesKcal: Double,
            proteinG: Double,
            carbsG: Double = 0,
            fatG: Double = 0,
            confidence: Double? = nil,
            assumptions: String? = nil,
            items: [ItemBreakdown] = []
        ) {
            self.foodName = foodName
            self.caloriesKcal = caloriesKcal
            self.proteinG = proteinG
            self.carbsG = carbsG
            self.fatG = fatG
            self.confidence = confidence
            self.assumptions = assumptions
            self.items = items
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            foodName = try c.decode(String.self, forKey: .foodName)
            caloriesKcal = try c.decode(Double.self, forKey: .caloriesKcal)
            proteinG = try c.decode(Double.self, forKey: .proteinG)
            carbsG = try c.decodeIfPresent(Double.self, forKey: .carbsG) ?? 0
            fatG = try c.decodeIfPresent(Double.self, forKey: .fatG) ?? 0
            confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
            assumptions = try c.decodeIfPresent(String.self, forKey: .assumptions)
            items = try c.decodeIfPresent([ItemBreakdown].self, forKey: .items) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(foodName, forKey: .foodName)
            try c.encode(caloriesKcal, forKey: .caloriesKcal)
            try c.encode(proteinG, forKey: .proteinG)
            try c.encode(carbsG, forKey: .carbsG)
            try c.encode(fatG, forKey: .fatG)
            try c.encodeIfPresent(confidence, forKey: .confidence)
            try c.encodeIfPresent(assumptions, forKey: .assumptions)
            try c.encode(items, forKey: .items)
        }
    }

    var id: UUID
    var createdAt: Date
    var consumptionDate: Date

    var mealType: MealType

    var photoFileName: String?

    var userText: String?
    var weightGrams: Double?
    var portionDescription: String?

    var analysis: Analysis

    enum CodingKeys: String, CodingKey {
        case id, createdAt, consumptionDate, mealType, photoFileName, userText, weightGrams, portionDescription, analysis
    }

    init(
        id: UUID,
        createdAt: Date,
        consumptionDate: Date,
        mealType: MealType,
        photoFileName: String?,
        userText: String?,
        weightGrams: Double?,
        portionDescription: String?,
        analysis: Analysis
    ) {
        self.id = id
        self.createdAt = createdAt
        self.consumptionDate = consumptionDate
        self.mealType = mealType
        self.photoFileName = photoFileName
        self.userText = userText
        self.weightGrams = weightGrams
        self.portionDescription = portionDescription
        self.analysis = analysis
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        consumptionDate = try c.decode(Date.self, forKey: .consumptionDate)
        mealType = try c.decodeIfPresent(MealType.self, forKey: .mealType) ?? .lunch
        photoFileName = try c.decodeIfPresent(String.self, forKey: .photoFileName)
        userText = try c.decodeIfPresent(String.self, forKey: .userText)
        weightGrams = try c.decodeIfPresent(Double.self, forKey: .weightGrams)
        portionDescription = try c.decodeIfPresent(String.self, forKey: .portionDescription)
        analysis = try c.decode(Analysis.self, forKey: .analysis)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(consumptionDate, forKey: .consumptionDate)
        try c.encode(mealType, forKey: .mealType)
        try c.encodeIfPresent(photoFileName, forKey: .photoFileName)
        try c.encodeIfPresent(userText, forKey: .userText)
        try c.encodeIfPresent(weightGrams, forKey: .weightGrams)
        try c.encodeIfPresent(portionDescription, forKey: .portionDescription)
        try c.encode(analysis, forKey: .analysis)
    }
}
