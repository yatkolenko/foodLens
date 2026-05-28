import Foundation

struct GoalProjection: Equatable {
    var dailyEnergyDeltaKcal: Double
    var weeklyWeightChangeKg: Double
    var estimatedDays: Int
    var estimatedDate: Date
}

struct TargetDatePlan: Equatable {
    var plan: NutritionPlan
    var targetDate: Date
    var targetWeightKg: Double
    var requiredCaloriesKcal: Double
    var dailyEnergyDeltaKcal: Double
    var weeklyWeightChangeKg: Double
    var achievableWithinSafeRange: Bool
}

struct NutritionPlan: Equatable {
    var bmrKcal: Double
    var maintenanceCaloriesKcal: Double
    var caloriesKcal: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double
    var waterLiters: Double
    var summary: String
    var projection: GoalProjection?
}

enum GoalsCalculator {
    private static let minimumCaloriesKcal = 1200.0
    private static let maximumCaloriesKcal = 4000.0

    static func bmrMifflinStJeor(sex: Sex, age: Int, heightCm: Double, weightKg: Double) -> Double {
        // Mifflin–St Jeor:
        // Men:    10w + 6.25h - 5a + 5
        // Women:  10w + 6.25h - 5a - 161
        let base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age)
        switch sex {
        case .male:
            return base + 5.0
        case .female:
            return base - 161.0
        }
    }

    static func plan(
        sex: Sex,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        goal: GoalType,
        targetWeightKg: Double? = nil,
        customCaloriesKcalPerDay: Double? = nil,
        referenceDate: Date = Date()
    ) -> NutritionPlan {
        let bmr = bmrMifflinStJeor(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg)
        let maintenance = (bmr * activity.multiplier).clamped(to: 1200...5000)

        let suggestedCalories: Double
        switch goal {
        case .lose:
            let deficit = (maintenance * 0.21).clamped(to: 350...700)
            suggestedCalories = maintenance - deficit
        case .maintain:
            suggestedCalories = maintenance
        case .gain:
            let surplus = (maintenance * 0.10).clamped(to: 180...320)
            suggestedCalories = maintenance + surplus
        }

        let calories = (customCaloriesKcalPerDay ?? suggestedCalories).clamped(to: minimumCaloriesKcal...maximumCaloriesKcal)
        let proteinG = (weightKg * goal.proteinPerKg).clamped(to: 50...260)
        let fatG = (weightKg * goal.fatPerKg).clamped(to: 45...140)
        let remainingCalories = max(200.0, calories - (proteinG * 4.0) - (fatG * 9.0))
        let carbsG = (remainingCalories / 4.0).clamped(to: 50...450)
        let fiberG = (calories / 1000.0 * 14.0).clamped(to: 25...45)
        let waterLiters = (weightKg * activity.waterMultiplierLitersPerKg).roundedToSingleDecimal()

        let projection = projectedGoalDate(
            currentWeightKg: weightKg,
            targetWeightKg: targetWeightKg,
            caloriesKcal: calories,
            maintenanceCaloriesKcal: maintenance,
            goal: goal,
            referenceDate: referenceDate
        )

        let summary = summaryText(
            goal: goal,
            bmr: bmr,
            maintenance: maintenance,
            calories: calories,
            activity: activity,
            projection: projection,
            isCustomCalories: customCaloriesKcalPerDay != nil
        )

        return NutritionPlan(
            bmrKcal: bmr,
            maintenanceCaloriesKcal: maintenance,
            caloriesKcal: calories.rounded(),
            proteinG: proteinG.rounded(),
            carbsG: carbsG.rounded(),
            fatG: fatG.rounded(),
            fiberG: fiberG.rounded(),
            waterLiters: waterLiters,
            summary: summary,
            projection: projection
        )
    }

    static func targetDatePlan(
        sex: Sex,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activity: ActivityLevel,
        goal: GoalType,
        targetWeightKg: Double,
        targetDate: Date,
        referenceDate: Date = Date()
    ) -> TargetDatePlan? {
        guard goal != .maintain else { return nil }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: referenceDate)
        let desiredDate = calendar.startOfDay(for: targetDate)
        let daysUntilTarget = calendar.dateComponents([.day], from: startDate, to: desiredDate).day ?? 0
        guard daysUntilTarget > 0 else { return nil }

        let weightDeltaKg: Double
        switch goal {
        case .lose:
            guard targetWeightKg < weightKg else { return nil }
            weightDeltaKg = weightKg - targetWeightKg
        case .gain:
            guard targetWeightKg > weightKg else { return nil }
            weightDeltaKg = targetWeightKg - weightKg
        case .maintain:
            return nil
        }

        let maintenance = (bmrMifflinStJeor(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg) * activity.multiplier)
            .clamped(to: minimumCaloriesKcal...5000)
        let dailyEnergyDelta = (weightDeltaKg * 7700.0) / Double(daysUntilTarget)
        let requiredCalories = goal == .lose
            ? maintenance - dailyEnergyDelta
            : maintenance + dailyEnergyDelta
        let safeCalories = requiredCalories.clamped(to: minimumCaloriesKcal...maximumCaloriesKcal)

        let plan = plan(
            sex: sex,
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            activity: activity,
            goal: goal,
            targetWeightKg: targetWeightKg,
            customCaloriesKcalPerDay: safeCalories,
            referenceDate: referenceDate
        )

        return TargetDatePlan(
            plan: plan,
            targetDate: desiredDate,
            targetWeightKg: targetWeightKg,
            requiredCaloriesKcal: requiredCalories,
            dailyEnergyDeltaKcal: dailyEnergyDelta.rounded(),
            weeklyWeightChangeKg: dailyEnergyDelta * 7.0 / 7700.0,
            achievableWithinSafeRange: abs(requiredCalories - safeCalories) < 0.1
        )
    }

    private static func projectedGoalDate(
        currentWeightKg: Double,
        targetWeightKg: Double?,
        caloriesKcal: Double,
        maintenanceCaloriesKcal: Double,
        goal: GoalType,
        referenceDate: Date
    ) -> GoalProjection? {
        guard goal != .maintain,
              let targetWeightKg else {
            return nil
        }

        let weightDeltaKg: Double
        let dailyEnergyDelta: Double

        switch goal {
        case .lose:
            guard targetWeightKg < currentWeightKg else { return nil }
            weightDeltaKg = currentWeightKg - targetWeightKg
            dailyEnergyDelta = maintenanceCaloriesKcal - caloriesKcal
        case .gain:
            guard targetWeightKg > currentWeightKg else { return nil }
            weightDeltaKg = targetWeightKg - currentWeightKg
            dailyEnergyDelta = caloriesKcal - maintenanceCaloriesKcal
        case .maintain:
            return nil
        }

        guard dailyEnergyDelta > 0 else { return nil }

        let weeklyWeightChangeKg = (dailyEnergyDelta * 7.0) / 7700.0
        guard weeklyWeightChangeKg >= 0.05 else { return nil }

        let estimatedDays = Int(ceil((weightDeltaKg * 7700.0) / dailyEnergyDelta))
        guard estimatedDays > 0,
              estimatedDays <= 3650,
              let estimatedDate = Calendar.current.date(byAdding: .day, value: estimatedDays, to: referenceDate) else {
            return nil
        }

        return GoalProjection(
            dailyEnergyDeltaKcal: dailyEnergyDelta.rounded(),
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            estimatedDays: estimatedDays,
            estimatedDate: estimatedDate
        )
    }

    private static func summaryText(
        goal: GoalType,
        bmr: Double,
        maintenance: Double,
        calories: Double,
        activity: ActivityLevel,
        projection: GoalProjection?,
        isCustomCalories: Bool
    ) -> String {
        let base = "Базовый обмен рассчитан по формуле Миффлина-Сан Жеора: около \(Int(bmr.rounded())) ккал. С учётом активности \"\(activity.title.lowercased())\" поддержание веса оценивается примерно в \(Int(maintenance.rounded())) ккал."

        switch goal {
        case .lose:
            let caloriesText = isCustomCalories
                ? " Вы вручную выбрали \(Int(calories.rounded())) ккал в день."
                : " Для похудения заложен умеренный дефицит, поэтому стартовый план составляет \(Int(calories.rounded())) ккал в день."
            if let projection {
                return base + caloriesText + " Это даёт ориентировочный темп около \(String(format: "%.2f", projection.weeklyWeightChangeKg)) кг в неделю."
            }
            return base + caloriesText
        case .maintain:
            return base + " План держится близко к уровню поддержки веса и помогает удерживать текущую форму."
        case .gain:
            if let projection {
                return base + " Для набора массы добавлен умеренный профицит калорий. Это даёт ориентировочный темп около \(String(format: "%.2f", projection.weeklyWeightChangeKg)) кг в неделю."
            }
            return base + " Для набора массы добавлен умеренный профицит калорий, чтобы рост шёл без слишком резкого набора жира."
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func roundedToSingleDecimal() -> Double {
        (self * 10).rounded() / 10
    }
}
