import SwiftUI

struct NutritionCalculatorView: View {
    @State private var sex: Sex = .male
    @State private var ageIndex = 15
    @State private var heightIndex = 50
    @State private var weightIndex = 92
    @State private var activity: ActivityLevel = .light
    @State private var goal: GoalType = .lose
    @State private var targetWeightIndex = 80
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    private let ages = Array(15...90)
    private let heightsCm = Array(130...220)
    private let weightsDisplay = (80...300).map { Double($0) / 2.0 }

    private var currentAge: Int { ages[ageIndex] }
    private var currentHeightCm: Double { Double(heightsCm[heightIndex]) }
    private var currentWeightKg: Double { weightsDisplay[weightIndex] }

    private var selectedTargetWeightKg: Double? {
        guard goal != .maintain else { return nil }
        return weightsDisplay[targetWeightIndex]
    }

    private var recommendedPlan: NutritionPlan {
        GoalsCalculator.plan(
            sex: sex,
            age: currentAge,
            heightCm: currentHeightCm,
            weightKg: currentWeightKg,
            activity: activity,
            goal: goal,
            targetWeightKg: goal != .maintain ? selectedTargetWeightKg : nil
        )
    }

    private var targetDateResult: TargetDatePlan? {
        guard let selectedTargetWeightKg else { return nil }
        return GoalsCalculator.targetDatePlan(
            sex: sex,
            age: currentAge,
            heightCm: currentHeightCm,
            weightKg: currentWeightKg,
            activity: activity,
            goal: goal,
            targetWeightKg: selectedTargetWeightKg,
            targetDate: targetDate
        )
    }

    private var isTargetWeightValid: Bool {
        guard let selectedTargetWeightKg else { return true }

        switch goal {
        case .lose:
            return selectedTargetWeightKg < currentWeightKg
        case .gain:
            return selectedTargetWeightKg > currentWeightKg
        case .maintain:
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Калькулятор плана")
                            .font(.headline)
                        Text("Можно прикинуть норму калорий и БЖУ по своим параметрам, а для похудения или набора массы — ещё и посмотреть, сколько калорий потребуется к выбранной дате.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                pickerCard(title: "Пол") {
                    Picker("Пол", selection: $sex) {
                        ForEach(Sex.allCases, id: \.self) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                compactMetricsGrid

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

                recommendedPlanCard

                if goal != .maintain {
                    targetDatePickerCard
                }

                if goal != .maintain, isTargetWeightValid, let targetDateResult {
                    targetDateCard(targetDateResult)
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.background)
        .navigationTitle("Калькулятор")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: weightIndex) { _, _ in
            adjustTargetWeightIfNeeded()
        }
        .onChange(of: goal) { _, _ in
            adjustTargetWeightIfNeeded()
        }
    }

    private var minimumTargetDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date().startOfDay) ?? Date()
    }

    private var compactMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                compactPickerCard(title: "Возраст") {
                    Picker("Возраст", selection: $ageIndex) {
                        ForEach(ages.indices, id: \.self) { index in
                            Text("\(ages[index]) лет").tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 82)
                    .clipped()
                }

                compactPickerCard(title: "Рост") {
                    Picker("Рост", selection: $heightIndex) {
                        ForEach(heightsCm.indices, id: \.self) { index in
                            Text("\(heightsCm[index]) см").tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 82)
                    .clipped()
                }
            }

            if goal == .maintain {
                compactPickerCard(title: "Текущий вес") {
                    weightPicker(selection: $weightIndex, label: "Вес")
                }
            } else {
                HStack(spacing: 10) {
                    compactPickerCard(title: "Текущий вес") {
                        weightPicker(selection: $weightIndex, label: "Вес")
                    }

                    compactPickerCard(title: "Целевой вес") {
                        weightPicker(selection: $targetWeightIndex, label: "Целевой вес")
                    }
                }

                if !isTargetWeightValid {
                    Text(goal == .lose ? "Целевой вес должен быть ниже текущего." : "Целевой вес должен быть выше текущего.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    private var recommendedPlanCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Рекомендованный план")
                    .font(.headline)

                statRow("Калории", "\(Int(recommendedPlan.caloriesKcal)) ккал")
                statRow("Белок", "\(Int(recommendedPlan.proteinG)) г")
                statRow("Углеводы", "\(Int(recommendedPlan.carbsG)) г")
                statRow("Жиры", "\(Int(recommendedPlan.fatG)) г")
                statRow("Клетчатка", "\(Int(recommendedPlan.fiberG)) г")
                statRow("Вода", String(format: "%.1f л", recommendedPlan.waterLiters))

                Divider().padding(.top, 4)
                Text(recommendedPlanDescription)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private var targetDatePickerCard: some View {
        pickerCard(title: "Дата результата") {
            VStack(alignment: .leading, spacing: 10) {
                DatePicker(
                    "Хочу увидеть результат к дате",
                    selection: $targetDate,
                    in: minimumTargetDate...,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ru_RU"))

                Text(targetDateHelperText)
                    .font(.footnote)
                    .foregroundStyle(targetDateHelperColor)
            }
        }
    }

    private var recommendedPlanDescription: String {
        if let projectionText = recommendedProjectionText {
            return "\(recommendedPlan.summary) \(projectionText)"
        }
        return recommendedPlan.summary
    }

    private var recommendedProjectionText: String? {
        guard goal != .maintain else { return nil }
        guard isTargetWeightValid else {
            return "Выберите корректный целевой вес, чтобы увидеть примерную дату достижения цели."
        }
        guard let targetWeight = selectedTargetWeightKg,
              let projection = recommendedPlan.projection else {
            return nil
        }

        let direction = goal == .lose ? "снижения" : "набора"
        return "При таком темпе цель \(formattedWeight(targetWeight)) для \(direction) веса ориентировочно достижима к \(longDate(projection.estimatedDate))."
    }

    private var targetDateHelperText: String {
        guard isTargetWeightValid else {
            return goal == .lose
                ? "Сначала выберите целевой вес ниже текущего."
                : "Сначала выберите целевой вес выше текущего."
        }
        guard let targetDateResult else {
            return "Выберите дату после сегодняшнего дня, и калькулятор покажет план под этот срок."
        }

        let weeklyChange = String(format: "%.2f", targetDateResult.weeklyWeightChangeKg)
        if targetDateResult.achievableWithinSafeRange {
            return "К выбранной дате нужен темп около \(weeklyChange) кг в неделю. План выглядит реалистично для стартового ориентира."
        }
        return "К выбранной дате нужен слишком резкий темп: около \(weeklyChange) кг в неделю. Ниже показан более мягкий вариант."
    }

    private var targetDateHelperColor: Color {
        guard isTargetWeightValid else { return .red }
        guard let targetDateResult else { return DesignTokens.textSecondary }
        return targetDateResult.achievableWithinSafeRange ? DesignTokens.textSecondary : .orange
    }

    private func targetDateCard(_ result: TargetDatePlan) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("План к выбранной дате")
                    .font(.headline)

                Text(targetDateVerdict(for: result))
                    .font(.footnote)
                    .foregroundStyle(result.achievableWithinSafeRange ? DesignTokens.textSecondary : .orange)

                if result.achievableWithinSafeRange {
                    Text("Чтобы прийти к \(formattedWeight(result.targetWeightKg)) к \(longDate(result.targetDate)), ориентир — около \(Int(result.plan.caloriesKcal)) ккал/день.")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    Text("Чтобы прийти к \(formattedWeight(result.targetWeightKg)) к \(longDate(result.targetDate)), потребовалось бы около \(Int(result.requiredCaloriesKcal.rounded())) ккал/день, что выходит за безопасный диапазон.")
                        .font(.footnote)
                        .foregroundStyle(.orange)

                    if let projection = result.plan.projection {
                        Text("При реалистичном плане \(Int(result.plan.caloriesKcal)) ккал/день ближайшая ориентировочная дата — \(longDate(projection.estimatedDate)).")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    } else {
                        Text("Калькулятор показывает ближайший безопасный вариант: \(Int(result.plan.caloriesKcal)) ккал/день.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                statRow(goal == .lose ? "Дефицит в день" : "Профицит в день", "\(Int(result.dailyEnergyDeltaKcal)) ккал")
                statRow("Ориентир в неделю", String(format: "%.2f кг", result.weeklyWeightChangeKg))
                statRow("Белок", "\(Int(result.plan.proteinG)) г")
                statRow("Углеводы", "\(Int(result.plan.carbsG)) г")
                statRow("Жиры", "\(Int(result.plan.fatG)) г")
            }
        }
    }

    private func targetDateVerdict(for result: TargetDatePlan) -> String {
        let weeklyChange = String(format: "%.2f", result.weeklyWeightChangeKg)
        if result.achievableWithinSafeRange {
            return "Выбранная дата требует темп около \(weeklyChange) кг в неделю. Это нормальный ориентир, если самочувствие и прогресс остаются стабильными."
        }
        return "Выбранная дата слишком близко для спокойного темпа: расчёт выходит за безопасный диапазон калорий."
    }

    private func compactPickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            content()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
        )
        .shadow(color: DesignTokens.cardShadow, radius: 6, x: 0, y: 2)
    }

    private func weightPicker(selection: Binding<Int>, label: String) -> some View {
        Picker(label, selection: selection) {
            ForEach(weightsDisplay.indices, id: \.self) { index in
                Text(formattedWeight(weightsDisplay[index])).tag(index)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 82)
        .clipped()
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

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func adjustTargetWeightIfNeeded() {
        guard goal != .maintain else { return }

        let currentWeight = currentWeightKg
        let targetWeight = weightsDisplay[targetWeightIndex]

        switch goal {
        case .lose where targetWeight >= currentWeight:
            let adjustedTarget = max(weightsDisplay.first ?? 40.0, currentWeight - 0.5)
            if let newIndex = weightsDisplay.firstIndex(where: { abs($0 - adjustedTarget) < 0.001 }) {
                targetWeightIndex = newIndex
            }
        case .gain where targetWeight <= currentWeight:
            let adjustedTarget = min(weightsDisplay.last ?? 150.0, currentWeight + 0.5)
            if let newIndex = weightsDisplay.firstIndex(where: { abs($0 - adjustedTarget) < 0.001 }) {
                targetWeightIndex = newIndex
            }
        default:
            break
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
}
