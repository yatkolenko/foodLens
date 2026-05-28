import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case profile
    case plan
}

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: FoodStore

    @State private var step: OnboardingStep = .welcome

    @State private var sex: Sex = .male
    @State private var ageIndex = 15
    @State private var heightIndex = 50
    @State private var weightIndex = 92
    @State private var activity: ActivityLevel = .light
    @State private var goal: GoalType = .maintain
    @State private var targetWeightIndex = 80
    @State private var customCaloriesKcal: Double?

    private let ages = Array(15...90)
    private let heightsCm = Array(130...220)
    private let weightsDisplay = (80...300).map { Double($0) / 2.0 }

    private var aiConfiguration: AIConfiguration {
        AIConfiguration.current
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

    private var isTargetWeightValid: Bool {
        guard let selectedTargetWeightKg else { return true }
        return selectedTargetWeightKg < currentWeightKg
    }

    private var caloriesRange: ClosedRange<Double> {
        let maintenance = max(recommendedPlan.maintenanceCaloriesKcal.rounded(.toNearestOrAwayFromZero), 1400)
        let upperBound = max(maintenance, 1400)
        return 1200...upperBound
    }

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            Group {
                switch step {
                case .welcome:
                    welcomePage
                case .profile:
                    profilePage
                case .plan:
                    planPage
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: weightIndex) { _, _ in
            adjustTargetWeightIfNeeded()
        }
        .onChange(of: goal) { _, newGoal in
            if newGoal != .lose {
                customCaloriesKcal = nil
            }
            adjustTargetWeightIfNeeded()
        }
    }

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 20)
            Text("FoodLens")
                .font(.largeTitle.bold())
                .foregroundStyle(DesignTokens.textPrimary)
            Text("Дневник питания с разбором блюд по фото. План калорий и макросов рассчитывается локально по формулам, а фото-анализ помогает заполнять блюда быстрее.")
                .font(.body)
                .foregroundStyle(DesignTokens.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Искусственный интеллект")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(aiConfiguration.isConfigured ? "Настроен и готов помогать с распознаванием блюд по фото." : "Пока не настроен. План питания и дневник будут работать, а распознавание фото можно будет включить позже.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
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

            VStack(spacing: 8) {
                Text("Создатель")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.textPrimary)

                Text("Dmytro Yatkolenko for personal use with my love Sofiia \(Text(Image(systemName: "heart.fill")).foregroundStyle(.red))")
                .font(.footnote)
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(DesignTokens.cardElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(DesignTokens.cardStroke, lineWidth: 1)
                    )
            )
            .shadow(color: DesignTokens.cardShadow, radius: 8, x: 0, y: 2)

            Spacer()

            Button {
                step = .profile
            } label: {
                Text("Далее")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var profilePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ваш профиль")
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

                pickerCard(title: "Вес") {
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
                    pickerCard(title: "До какого веса хотите похудеть") {
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
                            } else if let selectedTargetWeightKg {
                                Text("Сейчас: \(formattedWeight(currentWeightKg)), цель: \(formattedWeight(selectedTargetWeightKg)).")
                                    .font(.footnote)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                    }
                }

                Button {
                    preparePlanStep()
                } label: {
                    Text("Посмотреть план")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
                .disabled(!isTargetWeightValid)
            }
        }
    }

    private var planPage: some View {
        let plan = currentPlan

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ваш дневной план")
                    .font(.title2.bold())

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        metricRow("Калории", "\(Int(plan.caloriesKcal)) ккал")
                        metricRow("Белок", String(format: "%.0f г", plan.proteinG))
                        metricRow("Углеводы", String(format: "%.0f г", plan.carbsG))
                        metricRow("Жиры", String(format: "%.0f г", plan.fatG))
                        metricRow("Клетчатка", String(format: "%.0f г", plan.fiberG))
                        metricRow("Вода", String(format: "%.1f л", plan.waterLiters))
                    }
                }

                if goal == .lose {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Калории для снижения веса")
                                .font(.headline)

                            Stepper(value: caloriesBinding, in: caloriesRange, step: 50) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(Int((customCaloriesKcal ?? plan.caloriesKcal).rounded())) ккал/день")
                                        .font(.headline)
                                    Text("Можно подстроить калории вручную. Чем ниже калорийность, тем быстрее цель, но не опускайтесь слишком низко.")
                                        .font(.footnote)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            }

                            if let projection = plan.projection, let selectedTargetWeightKg {
                                Text("При таком плане вес \(formattedWeight(selectedTargetWeightKg)) ориентировочно можно достичь к \(longDate(projection.estimatedDate)) — примерно через \(formattedDuration(days: projection.estimatedDays)).")
                                    .font(.footnote)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            } else {
                                Text("При выбранной калорийности срок достижения цели не рассчитывается, потому что дефицит слишком маленький или отсутствует.")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Как рассчитан план")
                            .font(.headline)
                        Text(plan.summary)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                Button {
                    finishOnboarding(with: plan)
                } label: {
                    Text("Начать пользоваться")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
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

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
        .padding(.vertical, 6)
    }

    private var caloriesBinding: Binding<Double> {
        Binding(
            get: { customCaloriesKcal ?? recommendedPlan.caloriesKcal },
            set: { customCaloriesKcal = $0 }
        )
    }

    private func preparePlanStep() {
        adjustTargetWeightIfNeeded()
        if goal == .lose {
            customCaloriesKcal = recommendedPlan.caloriesKcal
        } else {
            customCaloriesKcal = nil
        }
        step = .plan
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

    private func finishOnboarding(with plan: NutritionPlan) {
        let profile = UserProfile(
            id: UUID(),
            createdAt: Date(),
            sex: sex,
            age: currentAge,
            heightCm: currentHeightCm,
            weightKg: currentWeightKg,
            activity: activity,
            goal: goal,
            goalTargetWeightKg: goal == .lose ? selectedTargetWeightKg : nil,
            customCaloriesKcalPerDay: goal == .lose ? customCaloriesKcal : nil,
            targetCaloriesKcalPerDay: plan.caloriesKcal,
            targetProteinGPerDay: plan.proteinG,
            targetCarbsGPerDay: plan.carbsG,
            targetFatGPerDay: plan.fatG,
            targetFiberGPerDay: plan.fiberG,
            targetWaterLitersPerDay: plan.waterLiters,
            aiPlanSummary: plan.summary
        )
        store.upsertProfile(profile)
        store.addWeightLog(weightKg: currentWeightKg, date: Date())
        store.completeOnboarding()
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

    private func formattedDuration(days: Int) -> String {
        if days < 14 {
            return "\(days) дн."
        }
        let weeks = Double(days) / 7.0
        if weeks < 8 {
            return String(format: "%.1f нед.", weeks)
        }
        let months = Double(days) / 30.0
        return String(format: "%.1f мес.", months)
    }
}
