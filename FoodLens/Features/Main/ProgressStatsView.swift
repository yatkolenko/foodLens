import Charts
import SwiftUI

struct ProgressStatsView: View {
    private enum NutritionHistoryRange: String, CaseIterable, Identifiable {
        case week
        case month
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .week:
                return "Неделя"
            case .month:
                return "Месяц"
            case .all:
                return "Весь период"
            }
        }
    }

    private enum NutritionMetric: String, CaseIterable, Identifiable {
        case calories
        case protein

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calories:
                return "Калории"
            case .protein:
                return "Белок"
            }
        }

        var unit: String {
            switch self {
            case .calories:
                return "ккал"
            case .protein:
                return "г"
            }
        }
    }

    private struct DailyGoalProgressPoint: Identifiable {
        let day: Date
        let caloriesActual: Double
        let caloriesTarget: Double
        let proteinActual: Double
        let proteinTarget: Double

        var id: Date { day }

        func actualValue(for metric: NutritionMetric) -> Double {
            switch metric {
            case .calories:
                return caloriesActual
            case .protein:
                return proteinActual
            }
        }

        func targetValue(for metric: NutritionMetric) -> Double {
            switch metric {
            case .calories:
                return caloriesTarget
            case .protein:
                return proteinTarget
            }
        }

        func percentOfGoal(for metric: NutritionMetric) -> Double {
            let target = max(targetValue(for: metric), 1)
            return actualValue(for: metric) / target * 100
        }
    }

    @EnvironmentObject private var store: FoodStore
    @State private var weightInput = ""
    @State private var showResetConfirm = false
    @State private var showDeleteWeightConfirm = false
    @State private var nutritionHistoryRange: NutritionHistoryRange = .month
    @State private var nutritionMetric: NutritionMetric = .calories
    @State private var selectedWeightLog: WeightLogEntry?
    @State private var selectedAdviceDay = Date().startOfDay
    @State private var isAnalyzingDay = false
    @State private var adviceErrorMessage: String?

    private var profile: UserProfile? { store.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let profile {
                        dailyNutritionInsightCard(profile)
                        nutritionHistoryCard(profile)
                    }

                    if !store.sortedWeightLogs().isEmpty {
                        weightChartCard
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Добавить вес")
                                .font(.headline)
                            HStack {
                                FloatingLabelTextField(
                                    title: "Вес (кг)",
                                    text: $weightInput,
                                    keyboardType: .decimalPad,
                                    textInputAutocapitalization: .never,
                                    autocorrectionDisabled: true
                                )
                                Button("Сохранить") {
                                    let v = Double(weightInput.replacingOccurrences(of: ",", with: "."))
                                    if let v, v > 30, v < 300 {
                                        store.addWeightLog(weightKg: v)
                                        weightInput = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(DesignTokens.accentGreen)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DesignTokens.background)
            .navigationTitle("Прогресс")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text("Сброс")
                    }
                }
            }
            .confirmationDialog("Удалить все данные и начать заново?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Сбросить", role: .destructive) {
                    store.resetAllUserData()
                }
                Button("Отмена", role: .cancel) {}
            }
            .confirmationDialog(
                "Удалить запись веса?",
                isPresented: $showDeleteWeightConfirm,
                titleVisibility: .visible,
                presenting: selectedWeightLog
            ) { log in
                Button("Удалить", role: .destructive) {
                    store.deleteWeightLog(id: log.id)
                    selectedWeightLog = nil
                }
                Button("Отмена", role: .cancel) {}
            } message: { log in
                Text("Запись \(formattedWeightValue(log.weightKg)) кг от \(shortDate(log.date)) будет удалена из истории веса.")
            }
        }
    }

    private func dailyNutritionInsightCard(_ profile: UserProfile) -> some View {
        let totals = store.totals(for: selectedAdviceDay)
        let advice = store.nutritionAdvice(on: selectedAdviceDay)
        let dayEntries = store.entries(for: selectedAdviceDay)

        return CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("День питания")
                            .font(.headline)
                        Text("\(dayEntries.count) записей")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

                    Spacer()

                    DatePicker(
                        "Дата",
                        selection: selectedAdviceDayBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                VStack(spacing: 10) {
                    dailyMetricRow(
                        title: "Калории",
                        used: totals.kcal,
                        target: profile.targetCaloriesKcalPerDay,
                        unit: "ккал",
                        isCalories: true
                    )

                    HStack(spacing: 10) {
                        compactMacroTile(title: "Белок", used: totals.protein, target: profile.targetProteinGPerDay)
                        compactMacroTile(title: "Углеводы", used: totals.carbs, target: profile.targetCarbsGPerDay)
                        compactMacroTile(title: "Жиры", used: totals.fat, target: profile.targetFatGPerDay)
                    }
                }

                Divider()

                if let advice {
                    adviceView(advice)
                } else {
                    Text("Совет для этой даты ещё не создан.")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                if let adviceErrorMessage {
                    Text(adviceErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    analyzeSelectedDay(profile)
                } label: {
                    if isAnalyzingDay {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(advice == nil ? "Анализ дня" : "Пересчитать совет", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isAnalyzingDay)
            }
        }
    }

    private func dailyMetricRow(title: String, used: Double, target: Double, unit: String, isCalories: Bool) -> some View {
        let remaining = target - used
        let percent = Int((used / max(target, 1) * 100).rounded())

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(percent)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(remaining >= 0 ? DesignTokens.accentGreen : .orange)
            }

            ProgressView(value: min(max(used, 0), max(target, 1)), total: max(target, 1))
                .tint(remaining >= 0 ? DesignTokens.accentGreen : .orange)

            HStack {
                Text("\(formattedMacroValue(used)) / \(formattedMacroValue(target)) \(unit)")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(remaining >= 0 ? "Осталось \(formattedMacroValue(remaining))" : "Перебор \(formattedMacroValue(abs(remaining)))")
                    .font(.caption)
                    .foregroundStyle(remaining >= 0 ? DesignTokens.textSecondary : .orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignTokens.surfaceMuted)
        )
    }

    private func compactMacroTile(title: String, used: Double, target: Double) -> some View {
        let remaining = target - used
        let percent = Int((used / max(target, 1) * 100).rounded())

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(percent)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(remaining >= 0 ? DesignTokens.textSecondary : .orange)
            }

            Text("\(formattedMacroValue(used)) / \(formattedMacroValue(target)) г")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignTokens.surfaceMuted)
        )
    }

    private func adviceView(_ advice: DailyNutritionAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(advice.summary)
                .font(.subheadline.weight(.semibold))

            if !advice.positives.isEmpty {
                adviceList(title: "Хорошо", items: advice.positives, color: DesignTokens.accentGreen)
            }

            if !advice.improvements.isEmpty {
                adviceList(title: "Улучшить", items: advice.improvements, color: .orange)
            }

            Text("Следующий шаг: \(advice.nextStep)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(DesignTokens.textPrimary)

            Text("Обновлено \(shortDate(advice.generatedAt))")
                .font(.caption2)
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func adviceList(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private func nutritionHistoryCard(_ profile: UserProfile) -> some View {
        let points = nutritionHistoryPoints(for: profile)
        let summary = nutritionHistorySummary(from: points, metric: nutritionMetric)

        return CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("История целей")
                    .font(.headline)

                Text("График показывает завершённые дни без сегодняшнего, чтобы было видно, как часто вы превышаете цель или не добираете её.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)

                Picker("Период", selection: $nutritionHistoryRange) {
                    ForEach(NutritionHistoryRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Показатель", selection: $nutritionMetric) {
                    ForEach(NutritionMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                if points.isEmpty {
                    Text("Появится после того, как в дневнике будет хотя бы один завершённый день с историей питания.")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    HStack(spacing: 12) {
                        legendDot(color: DesignTokens.accentGreen, title: "В пределах цели")
                        legendDot(color: .orange, title: nutritionMetric == .calories ? "Выше лимита" : "Ниже цели")
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        Chart {
                            RuleMark(y: .value("Цель", 100))
                                .foregroundStyle(DesignTokens.textSecondary.opacity(0.7))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            ForEach(points) { point in
                                BarMark(
                                    x: .value("День", point.day),
                                    y: .value("Процент", point.percentOfGoal(for: nutritionMetric))
                                )
                                .foregroundStyle(barColor(for: point, metric: nutritionMetric))
                            }
                        }
                        .frame(width: max(340, CGFloat(points.count) * 36), height: 220)
                        .chartYScale(domain: 0...chartUpperBound(for: points, metric: nutritionMetric))
                        .chartXAxis {
                            AxisMarks(values: chartAxisDates(for: points)) { value in
                                AxisGridLine().foregroundStyle(DesignTokens.cardStroke)
                                AxisTick().foregroundStyle(DesignTokens.cardStroke)
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(chartShortDate(date))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine().foregroundStyle(DesignTokens.cardStroke)
                                AxisValueLabel {
                                    if let percent = value.as(Double.self) {
                                        Text("\(Int(percent.rounded()))%")
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        statPill(title: summary.primaryTitle, value: "\(summary.primaryCount) дн.")
                        statPill(title: summary.secondaryTitle, value: "\(summary.secondaryCount) дн.")
                        statPill(title: "Среднее", value: "\(Int(summary.averagePercent.rounded()))%")
                    }

                    Text(summary.footer)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
    }

    private func analyzeSelectedDay(_ profile: UserProfile) {
        let day = selectedAdviceDay
        let entries = store.entries(for: day)
        let totals = store.totals(for: day)
        adviceErrorMessage = nil

        Task {
            isAnalyzingDay = true
            defer { isAnalyzingDay = false }

            do {
                let advice = try await AIClient.shared.analyzeNutritionDay(
                    AIClient.DayNutritionAnalysisInput(
                        day: day,
                        profile: profile,
                        entries: entries,
                        totals: totals
                    )
                )

                store.upsertNutritionAdvice(advice)
            } catch let error as AIClient.AIClientError {
                adviceErrorMessage = error.localizedDescription
            } catch {
                adviceErrorMessage = "Не удалось проанализировать день."
            }
        }
    }

    private var weightChartCard: some View {
        let logs = store.sortedWeightLogs()
        let chartBounds = weightChartBounds(for: logs)

        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Вес")
                    .font(.headline)
                Chart(logs) { log in
                    LineMark(
                        x: .value("Дата", log.date),
                        y: .value("кг", log.weightKg)
                    )
                    .foregroundStyle(DesignTokens.accentGreen)
                    PointMark(
                        x: .value("Дата", log.date),
                        y: .value("кг", log.weightKg)
                    )
                    .foregroundStyle(DesignTokens.accentYellow)

                    if let selectedWeightLog, selectedWeightLog.id == log.id {
                        RuleMark(x: .value("Выбранный день", selectedWeightLog.date))
                            .foregroundStyle(DesignTokens.textSecondary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                selectedWeightTooltip(selectedWeightLog)
                            }

                        PointMark(
                            x: .value("Выбранная дата", selectedWeightLog.date),
                            y: .value("Выбранный вес", selectedWeightLog.weightKg)
                        )
                        .symbolSize(180)
                        .foregroundStyle(DesignTokens.accentYellow)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: chartBounds)
                .chartYAxis {
                    AxisMarks(position: .leading, values: weightAxisValues(for: chartBounds)) { value in
                        AxisGridLine().foregroundStyle(DesignTokens.cardStroke)
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text("\(Int(weight.rounded()))")
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelectedWeightLog(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry,
                                            logs: logs
                                        )
                                    }
                            )
                    }
                }

                if let selectedWeightLog {
                    HStack {
                        Text("Выбрано: \(formattedWeightValue(selectedWeightLog.weightKg)) кг · \(shortDate(selectedWeightLog.date))")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textSecondary)

                        Spacer()

                        Button(role: .destructive) {
                            showDeleteWeightConfirm = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Text("Нажмите на точку графика, чтобы увидеть сохранённое значение веса.")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                if let last = logs.last, let first = logs.first, first.id != last.id {
                    let delta = last.weightKg - first.weightKg
                    Text(delta < 0 ? "С \(shortDate(first.date)): \(String(format: "%.1f", delta)) кг" : "С \(shortDate(first.date)): +\(String(format: "%.1f", delta)) кг")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d.MM.yy"
        return f.string(from: d)
    }

    private func selectedWeightTooltip(_ log: WeightLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formattedWeightValue(log.weightKg) + " кг")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textPrimary)
            Text(shortDate(log.date))
                .font(.caption2)
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignTokens.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignTokens.textSecondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignTokens.surfaceMuted)
        )
    }

    private func legendDot(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func weightChartBounds(for logs: [WeightLogEntry]) -> ClosedRange<Double> {
        guard let minWeight = logs.map(\.weightKg).min(),
              let maxWeight = logs.map(\.weightKg).max() else {
            return 45...100
        }

        let span = maxWeight - minWeight
        let padding: Double

        switch span {
        case ...1:
            padding = 1.5
        case ...2.5:
            padding = 1.2
        case ...5:
            padding = 1.5
        case ...10:
            padding = 2.0
        default:
            padding = min(4.0, max(2.0, span * 0.2))
        }

        let rawLower = max(30, minWeight - padding)
        let rawUpper = max(rawLower + max(3, span + padding * 2), maxWeight + padding)
        let lower = floor(rawLower)
        let upper = ceil(rawUpper)
        return lower...upper
    }

    private func weightAxisValues(for bounds: ClosedRange<Double>) -> [Double] {
        let span = bounds.upperBound - bounds.lowerBound
        let step: Double

        switch span {
        case ...6:
            step = 1
        case ...12:
            step = 2
        case ...24:
            step = 3
        default:
            step = 5
        }

        var values: [Double] = []
        var current = bounds.lowerBound
        while current <= bounds.upperBound + 0.1 {
            values.append(current)
            current += step
        }

        if values.last != bounds.upperBound {
            values.append(bounds.upperBound)
        }

        return values
    }

    private func updateSelectedWeightLog(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        logs: [WeightLogEntry]
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let relativeX = location.x - plotFrame.origin.x

        guard relativeX >= 0, relativeX <= plotFrame.size.width else { return }
        guard let selectedDate = proxy.value(atX: relativeX, as: Date.self) else { return }

        selectedWeightLog = logs.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private func formattedWeightValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func nutritionHistoryPoints(for profile: UserProfile) -> [DailyGoalProgressPoint] {
        let completedToday = Date().startOfDay
        let historicalEntries = store.entries.filter { $0.consumptionDate < completedToday }
        guard let firstLoggedDay = historicalEntries.map(\.consumptionDate).map(\.startOfDay).min() else {
            return []
        }

        guard let lastCompletedDay = Calendar.current.date(byAdding: .day, value: -1, to: completedToday) else {
            return []
        }

        let startDay: Date
        switch nutritionHistoryRange {
        case .week:
            startDay = max(firstLoggedDay, Calendar.current.date(byAdding: .day, value: -6, to: lastCompletedDay) ?? firstLoggedDay)
        case .month:
            startDay = max(firstLoggedDay, Calendar.current.date(byAdding: .day, value: -29, to: lastCompletedDay) ?? firstLoggedDay)
        case .all:
            startDay = firstLoggedDay
        }

        let groupedByDay = Dictionary(grouping: historicalEntries, by: { $0.consumptionDate.startOfDay })
        var points: [DailyGoalProgressPoint] = []
        var currentDay = startDay

        while currentDay <= lastCompletedDay {
            let entries = groupedByDay[currentDay] ?? []
            let calories = entries.reduce(0) { $0 + $1.analysis.caloriesKcal }
            let protein = entries.reduce(0) { $0 + $1.analysis.proteinG }

            points.append(
                DailyGoalProgressPoint(
                    day: currentDay,
                    caloriesActual: calories,
                    caloriesTarget: profile.targetCaloriesKcalPerDay,
                    proteinActual: protein,
                    proteinTarget: profile.targetProteinGPerDay
                )
            )

            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: currentDay) else {
                break
            }
            currentDay = nextDay
        }

        return points
    }

    private func barColor(for point: DailyGoalProgressPoint, metric: NutritionMetric) -> Color {
        switch metric {
        case .calories:
            return point.actualValue(for: .calories) <= point.targetValue(for: .calories)
                ? DesignTokens.accentGreen
                : .orange
        case .protein:
            return point.actualValue(for: .protein) >= point.targetValue(for: .protein)
                ? DesignTokens.accentGreen
                : .orange
        }
    }

    private func chartUpperBound(for points: [DailyGoalProgressPoint], metric: NutritionMetric) -> Double {
        let highestPercent = points.map { $0.percentOfGoal(for: metric) }.max() ?? 100
        let normalized = max(120, ceil(highestPercent / 20) * 20)
        return min(max(normalized, 120), 260)
    }

    private func chartAxisDates(for points: [DailyGoalProgressPoint]) -> [Date] {
        guard !points.isEmpty else { return [] }

        let stride: Int
        switch nutritionHistoryRange {
        case .week:
            stride = 1
        case .month:
            stride = 5
        case .all:
            stride = max(7, points.count / 6)
        }

        return points.enumerated().compactMap { index, point in
            if index == 0 || index == points.count - 1 || index % stride == 0 {
                return point.day
            }
            return nil
        }
    }

    private func chartShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = nutritionHistoryRange == .week ? "E\nd.MM" : "d.MM"
        return formatter.string(from: date)
    }

    private func nutritionHistorySummary(
        from points: [DailyGoalProgressPoint],
        metric: NutritionMetric
    ) -> (primaryTitle: String, primaryCount: Int, secondaryTitle: String, secondaryCount: Int, averagePercent: Double, footer: String) {
        let averagePercent = points.isEmpty ? 0 : points.map { $0.percentOfGoal(for: metric) }.reduce(0, +) / Double(points.count)

        switch metric {
        case .calories:
            let overLimitCount = points.filter { $0.actualValue(for: .calories) > $0.targetValue(for: .calories) }.count
            let withinLimitCount = points.count - overLimitCount
            return (
                primaryTitle: "Выше лимита",
                primaryCount: overLimitCount,
                secondaryTitle: "В пределах",
                secondaryCount: withinLimitCount,
                averagePercent: averagePercent,
                footer: "Оранжевые столбцы показывают дни, когда калорий было больше дневной цели."
            )
        case .protein:
            let reachedGoalCount = points.filter { $0.actualValue(for: .protein) >= $0.targetValue(for: .protein) }.count
            let belowGoalCount = points.count - reachedGoalCount
            return (
                primaryTitle: "Цель достигнута",
                primaryCount: reachedGoalCount,
                secondaryTitle: "Не добрали",
                secondaryCount: belowGoalCount,
                averagePercent: averagePercent,
                footer: "Оранжевые столбцы показывают дни, когда белка было меньше дневной цели."
            )
        }
    }

    private func formattedGrams(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value)) г"
        }

        return String(format: "%.1f г", value)
    }

    private func formattedMacroValue(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.1f", value)
    }

    private var selectedAdviceDayBinding: Binding<Date> {
        Binding(
            get: { selectedAdviceDay },
            set: {
                selectedAdviceDay = $0.startOfDay
                adviceErrorMessage = nil
            }
        )
    }
}
