import Foundation

enum Sex: String, Codable, CaseIterable {
    case male
    case female

    var title: String {
        switch self {
        case .male: return "Мужской"
        case .female: return "Женский"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: return "Сидячий образ жизни"
        case .light: return "Лёгкая активность"
        case .moderate: return "Умеренная"
        case .active: return "Высокая"
        case .veryActive: return "Очень высокая"
        }
    }

    var description: String {
        switch self {
        case .sedentary:
            return "Почти нет тренировок, в основном сидячая работа и мало движения в течение дня."
        case .light:
            return "1-3 лёгких тренировки в неделю или 6-8 тысяч шагов в день без тяжёлых нагрузок."
        case .moderate:
            return "3-5 тренировок в неделю или активный образ жизни с регулярным движением."
        case .active:
            return "5-6 интенсивных тренировок в неделю, много шагов или физически активная работа."
        case .veryActive:
            return "Тяжёлые тренировки почти каждый день, спорт дважды в день или очень физически тяжёлая работа."
        }
    }

    var waterMultiplierLitersPerKg: Double {
        switch self {
        case .sedentary: return 0.03
        case .light: return 0.035
        case .moderate: return 0.038
        case .active: return 0.042
        case .veryActive: return 0.046
        }
    }
}

enum GoalType: String, Codable, CaseIterable {
    case lose
    case maintain
    case gain

    var proteinPerKg: Double {
        switch self {
        case .lose: return 2.0
        case .maintain: return 1.8
        case .gain: return 1.9
        }
    }

    var fatPerKg: Double {
        switch self {
        case .lose: return 0.85
        case .maintain: return 0.95
        case .gain: return 1.0
        }
    }

    var title: String {
        switch self {
        case .lose: return "Похудение"
        case .maintain: return "Поддержание веса"
        case .gain: return "Набор массы"
        }
    }

    var description: String {
        switch self {
        case .lose:
            return "План с дефицитом калорий для снижения веса и сохранения мышечной массы."
        case .maintain:
            return "План около уровня поддержки, чтобы удерживать текущий вес."
        case .gain:
            return "План с умеренным профицитом калорий для набора массы."
        }
    }
}

struct UserProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var createdAt: Date

    var sex: Sex
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var activity: ActivityLevel
    var goal: GoalType
    var goalTargetWeightKg: Double?
    var customCaloriesKcalPerDay: Double?

    var targetCaloriesKcalPerDay: Double
    var targetProteinGPerDay: Double
    var targetCarbsGPerDay: Double
    var targetFatGPerDay: Double
    var targetFiberGPerDay: Double
    var targetWaterLitersPerDay: Double

    /// Краткое пояснение логики расчёта плана.
    var aiPlanSummary: String?

    enum CodingKeys: String, CodingKey {
        case id, createdAt, sex, age, heightCm, weightKg, activity, goal
        case goalTargetWeightKg, customCaloriesKcalPerDay
        case targetCaloriesKcalPerDay, targetProteinGPerDay
        case targetCarbsGPerDay, targetFatGPerDay, targetFiberGPerDay, targetWaterLitersPerDay
        case aiPlanSummary
    }

    init(
        id: UUID,
        createdAt: Date,
        sex: Sex,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        goal: GoalType,
        goalTargetWeightKg: Double? = nil,
        customCaloriesKcalPerDay: Double? = nil,
        targetCaloriesKcalPerDay: Double,
        targetProteinGPerDay: Double,
        targetCarbsGPerDay: Double,
        targetFatGPerDay: Double,
        targetFiberGPerDay: Double,
        targetWaterLitersPerDay: Double,
        aiPlanSummary: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sex = sex
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activity = activity
        self.goal = goal
        self.goalTargetWeightKg = goalTargetWeightKg
        self.customCaloriesKcalPerDay = customCaloriesKcalPerDay
        self.targetCaloriesKcalPerDay = targetCaloriesKcalPerDay
        self.targetProteinGPerDay = targetProteinGPerDay
        self.targetCarbsGPerDay = targetCarbsGPerDay
        self.targetFatGPerDay = targetFatGPerDay
        self.targetFiberGPerDay = targetFiberGPerDay
        self.targetWaterLitersPerDay = targetWaterLitersPerDay
        self.aiPlanSummary = aiPlanSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        sex = try c.decode(Sex.self, forKey: .sex)
        age = try c.decode(Int.self, forKey: .age)
        heightCm = try c.decode(Double.self, forKey: .heightCm)
        weightKg = try c.decode(Double.self, forKey: .weightKg)
        activity = try c.decode(ActivityLevel.self, forKey: .activity)
        goal = try c.decode(GoalType.self, forKey: .goal)
        goalTargetWeightKg = try c.decodeIfPresent(Double.self, forKey: .goalTargetWeightKg)
        customCaloriesKcalPerDay = try c.decodeIfPresent(Double.self, forKey: .customCaloriesKcalPerDay)
        targetCaloriesKcalPerDay = try c.decode(Double.self, forKey: .targetCaloriesKcalPerDay)
        targetProteinGPerDay = try c.decode(Double.self, forKey: .targetProteinGPerDay)
        targetCarbsGPerDay = try c.decodeIfPresent(Double.self, forKey: .targetCarbsGPerDay) ?? 200
        targetFatGPerDay = try c.decodeIfPresent(Double.self, forKey: .targetFatGPerDay) ?? 65
        targetFiberGPerDay = try c.decodeIfPresent(Double.self, forKey: .targetFiberGPerDay) ?? 28
        targetWaterLitersPerDay = try c.decodeIfPresent(Double.self, forKey: .targetWaterLitersPerDay) ?? 2.5
        aiPlanSummary = try c.decodeIfPresent(String.self, forKey: .aiPlanSummary)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(sex, forKey: .sex)
        try c.encode(age, forKey: .age)
        try c.encode(heightCm, forKey: .heightCm)
        try c.encode(weightKg, forKey: .weightKg)
        try c.encode(activity, forKey: .activity)
        try c.encode(goal, forKey: .goal)
        try c.encodeIfPresent(goalTargetWeightKg, forKey: .goalTargetWeightKg)
        try c.encodeIfPresent(customCaloriesKcalPerDay, forKey: .customCaloriesKcalPerDay)
        try c.encode(targetCaloriesKcalPerDay, forKey: .targetCaloriesKcalPerDay)
        try c.encode(targetProteinGPerDay, forKey: .targetProteinGPerDay)
        try c.encode(targetCarbsGPerDay, forKey: .targetCarbsGPerDay)
        try c.encode(targetFatGPerDay, forKey: .targetFatGPerDay)
        try c.encode(targetFiberGPerDay, forKey: .targetFiberGPerDay)
        try c.encode(targetWaterLitersPerDay, forKey: .targetWaterLitersPerDay)
        try c.encodeIfPresent(aiPlanSummary, forKey: .aiPlanSummary)
    }
}
