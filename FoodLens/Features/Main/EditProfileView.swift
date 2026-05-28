import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FoodStore

    private let profile: UserProfile

    @State private var sex: Sex
    @State private var ageIndex: Int
    @State private var heightIndex: Int
    @State private var weightIndex: Int
    @State private var activity: ActivityLevel
    @State private var goal: GoalType
    @State private var targetWeightIndex: Int
    @State private var customCaloriesKcal: Double?

    private let ages = Array(15...90)
    private let heightsCm = Array(130...220)
    private let weightsDisplay = (80...300).map { Double($0) / 2.0 }

    init(profile: UserProfile) {
        self.profile = profile

        let ageIndex = max(0, min(75, profile.age - 15))
        let heightIndex = max(0, min(90, Int(profile.heightCm.rounded()) - 130))
        let weightIndex = Self.closestWeightIndex(in: (80...300).map { Double($0) / 2.0 }, target: profile.weightKg)
        let targetIndex = Self.closestWeightIndex(
            in: (80...300).map { Double($0) / 2.0 },
            target: profile.goalTargetWeightKg ?? max(40.0, profile.weightKg - 6.0)
        )

        _sex = State(initialValue: profile.sex)
        _ageIndex = State(initialValue: ageIndex)
        _heightIndex = State(initialValue: heightIndex)
        _weightIndex = State(initialValue: weightIndex)
        _activity = State(initialValue: profile.activity)
        _goal = State(initialValue: profile.goal)
        _targetWeightIndex = State(initialValue: targetIndex)
        _customCaloriesKcal = State(initialValue: profile.customCaloriesKcalPerDay)
    }

    private var currentAge: Int { ages[ageIndex] }
    private var currentHeightCm: Double { Double(heightsCm[heightIndex]) }
    private var currentWeightKg: Double { weightsDisplay[weightIndex] }
    private var selectedTargetWeightKg: Double? {
        goal == .lose ? weightsDisplay[targetWeightIndex] : nil
    }

    private var recommendedPlan: NutritionPlan {
        GoalsCalculator.plan(
            sex: sex,
            age: currentAge,
            heightCm: currentHeightCm,
            weightKg: currentWeightKg,
            activity: activity,
            goal: goal,
            targetWeightKg: selectedTargetWeightKg
        )
    }

    private var currentPlan: NutritionPlan {
        GoalsCalculator.plan(
            sex: sex,
            age: currentAge,
            heightCm: currentHeightCm,
            weightKg: currentWeightKg,
            activity: activity,
            goal: goal,
            targetWeightKg: selectedTargetWeightKg,
            customCaloriesKcalPerDay: goal == .lose ? customCaloriesKcal : nil
        )
    }

    private var caloriesRange: ClosedRange<Double> {
        let maintenance = max(recommendedPlan.maintenanceCaloriesKcal.rounded(.toNearestOrAwayFromZero), 1400)
        return 1200...maintenance
    }

    private var isTargetWeightValid: Bool {
        guard let selectedTargetWeightKg else { return true }
        return selectedTargetWeightKg < currentWeightKg
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Параметры")
                    .font(.title2.bold())

                pickerCard(title: "Пол") {
                    Picker("Пол", selection: $sex) {
                        ForEach(Sex.allCases, id: \.self) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                pickerCard(title: "Возраст") {
                    Picker("Возраст", selection: $ageIndex) {
                        ForEach(ages.indices, id: \.self) { index in
                            Text("\(ages[index]) лет").tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                pickerCard(title: "Рост") {
                    Picker("Рост", selection: $heightIndex) {
                        ForEach(heightsCm.indices, id: \.self) { index in
                            Text("\(heightsCm[index]) см").tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                pickerCard(title: "Текущий вес") {
                    Picker("Вес", selection: $weightIndex) {
                        ForEach(weightsDisplay.indices, id: \.self) { index in
                            Text(formattedWeight(weightsDisplay[index])).tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                pickerCard(title: "Активность") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Активность", selection: $activity) {
                            ForEach(ActivityLevel.allCases, id: \.self) { value in
                                Text(value.title).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(activity.description)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                pickerCard(title: "Цель") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Цель", selection: $goal) {
                            ForEach(GoalType.allCases, id: \.self) { value in
                                Text(value.title).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(goal.description)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                if goal == .lose {
                    pickerCard(title: "Целевой вес") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Целевой вес", selection: $targetWeightIndex) {
                                ForEach(weightsDisplay.indices, id: \.self) { index in
                                    Text(formattedWeight(weightsDisplay[index])).tag(index)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)

                            if !isTargetWeightValid {
                                Text("Целевой вес должен быть ниже текущего.")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Калории для снижения веса")
                                .font(.headline)
                            Stepper(value: caloriesBinding, in: caloriesRange, step: 50) {
                                Text("\(Int((customCaloriesKcal ?? recommendedPlan.caloriesKcal).rounded())) ккал/день")
                                    .font(.headline)
                            }

                            if let projection = currentPlan.projection, let targetWeight = selectedTargetWeightKg {
                                Text("При этом плане вес \(formattedWeight(targetWeight)) ориентировочно можно достичь к \(longDate(projection.estimatedDate)).")
                                    .font(.footnote)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            } else {
                                Text("Если калории поднять слишком высоко, дефицит станет слишком маленьким и надёжный прогноз по дате исчезнет.")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Пересчёт плана")
                            .font(.headline)
                        Text(currentPlan.summary)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                Button {
                    saveProfile()
                } label: {
                    Text("Сохранить и пересчитать")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isTargetWeightValid)
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.background)
        .navigationTitle("Изменить профиль")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: sex) { _, _ in
            resetCaloriesOverride()
        }
        .onChange(of: ageIndex) { _, _ in
            resetCaloriesOverride()
        }
        .onChange(of: heightIndex) { _, _ in
            resetCaloriesOverride()
        }
        .onChange(of: weightIndex) { _, _ in
            adjustTargetWeightIfNeeded()
            resetCaloriesOverride()
        }
        .onChange(of: activity) { _, _ in
            resetCaloriesOverride()
        }
        .onChange(of: goal) { _, newGoal in
            if newGoal == .lose {
                customCaloriesKcal = nil
            } else {
                customCaloriesKcal = nil
            }
            adjustTargetWeightIfNeeded()
        }
    }

    private var caloriesBinding: Binding<Double> {
        Binding(
            get: { customCaloriesKcal ?? recommendedPlan.caloriesKcal },
            set: { customCaloriesKcal = $0 }
        )
    }

    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(DesignTokens.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
        )
        .shadow(color: DesignTokens.cardShadow, radius: 8, x: 0, y: 2)
    }

    private func saveProfile() {
        let plan = currentPlan
        let updatedProfile = UserProfile(
            id: profile.id,
            createdAt: profile.createdAt,
            sex: sex,
            age: currentAge,
            heightCm: currentHeightCm,
            weightKg: currentWeightKg,
            activity: activity,
            goal: goal,
            goalTargetWeightKg: goal == .lose ? selectedTargetWeightKg : nil,
            customCaloriesKcalPerDay: goal == .lose ? savedCustomCaloriesValue : nil,
            targetCaloriesKcalPerDay: plan.caloriesKcal,
            targetProteinGPerDay: plan.proteinG,
            targetCarbsGPerDay: plan.carbsG,
            targetFatGPerDay: plan.fatG,
            targetFiberGPerDay: plan.fiberG,
            targetWaterLitersPerDay: plan.waterLiters,
            aiPlanSummary: plan.summary
        )

        store.upsertProfile(updatedProfile)

        if abs(profile.weightKg - currentWeightKg) > 0.001 {
            store.addWeightLog(weightKg: currentWeightKg, date: Date())
        }

        dismiss()
    }

    private var savedCustomCaloriesValue: Double? {
        guard goal == .lose, let customCaloriesKcal else { return nil }
        return abs(customCaloriesKcal - recommendedPlan.caloriesKcal) < 0.1 ? nil : customCaloriesKcal
    }

    private func resetCaloriesOverride() {
        customCaloriesKcal = nil
    }

    private func adjustTargetWeightIfNeeded() {
        guard goal == .lose else { return }
        let currentWeight = currentWeightKg
        let targetWeight = weightsDisplay[targetWeightIndex]

        if targetWeight >= currentWeight {
            let adjustedTarget = max(weightsDisplay.first ?? 40.0, currentWeight - 0.5)
            if let newIndex = weightsDisplay.firstIndex(where: { abs($0 - adjustedTarget) < 0.001 }) {
                targetWeightIndex = newIndex
            }
        }
    }

    private func formattedWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f кг", value)
        }
        return String(format: "%.1f кг", value)
    }

    private func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private static func closestWeightIndex(in values: [Double], target: Double) -> Int {
        values.enumerated()
            .min(by: { abs($0.element - target) < abs($1.element - target) })?
            .offset ?? 0
    }
}
