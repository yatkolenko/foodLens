import SwiftUI

struct QuickVoiceMealView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FoodStore
    @StateObject private var speechTranscriber = SpeechTranscriber()

    let day: Date

    @State private var dictatedText = ""
    @State private var dictationSeedText = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var analysisResult: AIClient.MealAnalysisResult?
    @State private var draftItems: [DraftFoodItem] = []
    @State private var didAttemptAutoStart = false

    init(day: Date) {
        self.day = day.startOfDay
    }

    private var trimmedText: String {
        dictatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAnalyze: Bool {
        !isAnalyzing && !trimmedText.isEmpty
    }

    private var canStartDictation: Bool {
        !isAnalyzing && speechTranscriber.isSupported && speechTranscriber.isRecognizerAvailable
    }

    private var canAdd: Bool {
        !draftItems.isEmpty && !isAnalyzing
    }

    private var draftTotals: MacroTotals {
        draftItems.reduce(MacroTotals()) { partial, item in
            MacroTotals(
                calories: partial.calories + item.caloriesKcal,
                protein: partial.protein + item.proteinG,
                carbs: partial.carbs + item.carbsG,
                fat: partial.fat + item.fatG,
                weight: partial.weight + (item.estimatedWeightGrams ?? 0)
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                voiceInputCard

                if !draftItems.isEmpty {
                    reviewHeaderCard
                    draftItemsCard
                    totalsCard
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                analyzeButton
            }
            .padding(16)
            .padding(.bottom, draftItems.isEmpty ? 0 : 88)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignTokens.background)
        .navigationTitle("Быстро добавить")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Закрыть") {
                    dismiss()
                }
            }
        }
        .overlay {
            if isAnalyzing {
                analyzingOverlay
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !draftItems.isEmpty {
                bottomActions
            }
        }
        .onAppear {
            attemptAutoStartDictationIfNeeded()
        }
        .onChange(of: speechTranscriber.transcript) { _, transcript in
            applyDictationTranscript(transcript)
        }
        .onChange(of: speechTranscriber.errorMessage) { _, message in
            guard let message, !message.isEmpty else { return }
            errorMessage = message
        }
        .onDisappear {
            speechTranscriber.stopTranscribing()
        }
    }

    private var voiceInputCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        toggleDictation()
                    } label: {
                        Image(systemName: speechTranscriber.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(
                                Circle()
                                    .fill(speechTranscriber.isRecording ? Color.red : DesignTokens.accentGreen)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStartDictation && !speechTranscriber.isRecording)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(speechTranscriber.isRecording ? "Слушаю" : "Голосовой ввод")
                            .font(.headline)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

                    Spacer()
                }

                FloatingLabelTextField(
                    title: "Описание",
                    text: $dictatedText,
                    axis: .vertical,
                    lineLimit: 5,
                    minHeight: 118
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.quickTokens, id: \.self) { token in
                            Button(token) {
                                appendToken(token)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(DesignTokens.accentGreen)
                        }
                    }
                }
            }
        }
    }

    private var reviewHeaderCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Проверка")
                        .font(.headline)
                    Spacer()
                    Text("\(draftItems.count) поз.")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DesignTokens.surfaceSoftGreen))
                }

                if let foodName = analysisResult?.analysis.foodName, !foodName.isEmpty {
                    Text(foodName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.textPrimary)
                }

                if let assumptions = analysisResult?.analysis.assumptions, !assumptions.isEmpty {
                    Text(assumptions)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
    }

    private var draftItemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Позиции")
                .font(.title3.bold())
                .padding(.horizontal, 2)

            ForEach($draftItems) { $item in
                foodDraftRow($item)
            }
        }
    }

    private func foodDraftRow(_ item: Binding<DraftFoodItem>) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.wrappedValue.name)
                            .font(.headline)
                        Text(item.wrappedValue.quantityDescription)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.accentGreen)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        removeDraftItem(id: item.wrappedValue.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                HStack(spacing: 8) {
                    macroChip("Ккал", formattedNumber(item.wrappedValue.caloriesKcal))
                    macroChip("Б", formattedNumber(item.wrappedValue.proteinG))
                    macroChip("У", formattedNumber(item.wrappedValue.carbsG))
                    macroChip("Ж", formattedNumber(item.wrappedValue.fatG))
                }

                HStack(spacing: 10) {
                    Label(item.wrappedValue.mealType.title, systemImage: item.wrappedValue.mealType.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.accentGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(DesignTokens.surfaceSoftGreen))

                    if let weight = item.wrappedValue.estimatedWeightGrams {
                        Text("\(formattedNumber(weight)) г")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

                    Spacer()
                }
            }
        }
    }

    private func macroChip(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignTokens.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private var totalsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Итого")
                    .font(.headline)

                HStack(spacing: 10) {
                    totalBadge(title: "Калории", value: "\(formattedNumber(draftTotals.calories)) ккал")
                    totalBadge(title: "Белки", value: "\(formattedNumber(draftTotals.protein)) г")
                }

                HStack(spacing: 10) {
                    totalBadge(title: "Углеводы", value: "\(formattedNumber(draftTotals.carbs)) г")
                    totalBadge(title: "Жиры", value: "\(formattedNumber(draftTotals.fat)) г")
                }

                if draftTotals.weight > 0 {
                    Text("Оценочный вес: \(formattedNumber(draftTotals.weight)) г")
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
    }

    private func totalBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DesignTokens.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private var analyzeButton: some View {
        Button {
            analyze()
        } label: {
            if isAnalyzing {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label(draftItems.isEmpty ? "Проанализировать" : "Пересчитать", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canAnalyze)
    }

    private var bottomActions: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Отменить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryOutlineButtonStyle())

                Button {
                    saveEntries()
                } label: {
                    Text("Добавить")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAdd)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(DesignTokens.accentGreen)
                    .scaleEffect(1.25)

                Text("Разбираем еду")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignTokens.textPrimary)

                Text("Запрос выполняется, ожидаем ответ от ИИ.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(maxWidth: 260)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DesignTokens.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DesignTokens.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: DesignTokens.cardShadow.opacity(0.9), radius: 18, x: 0, y: 6)
            )
            .padding(.horizontal, 28)
        }
    }

    private var statusText: String {
        if speechTranscriber.isRecording {
            return "Можно говорить день целиком, с паузами."
        }
        if !trimmedText.isEmpty {
            return "Проверьте текст перед анализом."
        }
        return "Нажмите микрофон или вставьте список еды."
    }

    private func attemptAutoStartDictationIfNeeded() {
        guard !didAttemptAutoStart else { return }
        didAttemptAutoStart = true
        guard canStartDictation else { return }
        toggleDictation()
    }

    private func toggleDictation() {
        if speechTranscriber.isRecording {
            speechTranscriber.stopTranscribing()
            return
        }

        dictationSeedText = trimmedText
        errorMessage = nil

        Task {
            do {
                try await speechTranscriber.startTranscribing(contextualStrings: Self.speechContextualStrings)
            } catch let error as SpeechTranscriber.SpeechTranscriberError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Не удалось начать диктовку."
            }
        }
    }

    private func applyDictationTranscript(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }

        if dictationSeedText.isEmpty {
            dictatedText = trimmedTranscript
        } else {
            dictatedText = "\(dictationSeedText) \(trimmedTranscript)"
        }
    }

    private func analyze() {
        guard canAnalyze else { return }
        speechTranscriber.stopTranscribing()
        errorMessage = nil
        let explicitSections = Self.parsedMealSections(from: trimmedText)

        Task {
            isAnalyzing = true
            defer { isAnalyzing = false }

            do {
                let result: AIClient.MealAnalysisResult

                if explicitSections.count >= 2 {
                    result = try await analyzeExplicitMealSections(explicitSections)
                } else {
                    result = try await AIClient.shared.analyzeFood(
                        image: nil,
                        userText: trimmedText,
                        weightGrams: nil,
                        portionDescription: nil,
                        mealContextDate: analysisContextDate()
                    )
                }

                applyAnalysisResult(result)
            } catch let error as AIClient.AIClientError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Ошибка сети."
            }
        }
    }

    private func analyzeExplicitMealSections(_ sections: [ParsedMealSection]) async throws -> AIClient.MealAnalysisResult {
        var mergedItems: [FoodEntry.Analysis.ItemBreakdown] = []
        var assumptions: [String] = []
        var confidenceSum: Double = 0
        var confidenceCount = 0

        for section in sections {
            let result = try await AIClient.shared.analyzeFood(
                image: nil,
                userText: section.analysisText,
                weightGrams: nil,
                portionDescription: nil,
                mealContextDate: analysisContextDate(for: section.mealType)
            )

            let sectionItems = result.analysis.items.isEmpty
                ? [FoodEntry.Analysis.ItemBreakdown(
                    name: result.analysis.foodName,
                    quantityDescription: result.estimatedWeightGrams.map { "\(formattedNumber($0)) г" } ?? "1 порция",
                    mealType: section.mealType,
                    estimatedWeightGrams: result.estimatedWeightGrams,
                    caloriesKcal: result.analysis.caloriesKcal,
                    proteinG: result.analysis.proteinG,
                    carbsG: result.analysis.carbsG,
                    fatG: result.analysis.fatG
                )]
                : result.analysis.items.map { item in
                    FoodEntry.Analysis.ItemBreakdown(
                        name: item.name,
                        quantityDescription: item.quantityDescription,
                        mealType: section.mealType,
                        estimatedWeightGrams: item.estimatedWeightGrams,
                        caloriesKcal: item.caloriesKcal,
                        proteinG: item.proteinG,
                        carbsG: item.carbsG,
                        fatG: item.fatG
                    )
                }

            mergedItems.append(contentsOf: sectionItems)

            if let confidence = result.analysis.confidence {
                confidenceSum += confidence
                confidenceCount += 1
            }

            if let sectionAssumptions = result.analysis.assumptions,
               !sectionAssumptions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                assumptions.append("\(section.mealType.title): \(sectionAssumptions)")
            }
        }

        let totals = mergedItems.reduce(MacroTotals()) { partial, item in
            MacroTotals(
                calories: partial.calories + item.caloriesKcal,
                protein: partial.protein + item.proteinG,
                carbs: partial.carbs + item.carbsG,
                fat: partial.fat + item.fatG,
                weight: partial.weight + (item.estimatedWeightGrams ?? 0)
            )
        }

        return AIClient.MealAnalysisResult(
            analysis: FoodEntry.Analysis(
                foodName: "Рацион за день",
                caloriesKcal: totals.calories,
                proteinG: totals.protein,
                carbsG: totals.carbs,
                fatG: totals.fat,
                confidence: confidenceCount > 0 ? confidenceSum / Double(confidenceCount) : nil,
                assumptions: assumptions.isEmpty ? "Текст разбит на приёмы пищи по заголовкам пользователя." : assumptions.joined(separator: "\n"),
                items: mergedItems
            ),
            estimatedWeightGrams: totals.weight > 0 ? totals.weight : nil,
            inferredMealType: sections.first?.mealType
        )
    }

    private func applyAnalysisResult(_ result: AIClient.MealAnalysisResult) {
        let mentionedMealTypes = MealType.mentionedTypes(inText: trimmedText)
        let fallbackMealType = MealType.inferred(fromText: trimmedText)
            ?? result.inferredMealType
            ?? MealType.inferredFromClock(analysisContextDate())

        analysisResult = result

        let items = result.analysis.items.isEmpty
            ? [FoodEntry.Analysis.ItemBreakdown(
                name: result.analysis.foodName,
                quantityDescription: result.estimatedWeightGrams.map { "\(formattedNumber($0)) г" } ?? "1 порция",
                mealType: fallbackMealType,
                estimatedWeightGrams: result.estimatedWeightGrams,
                caloriesKcal: result.analysis.caloriesKcal,
                proteinG: result.analysis.proteinG,
                carbsG: result.analysis.carbsG,
                fatG: result.analysis.fatG
            )]
            : result.analysis.items

        let aiMealTypes = Set(items.compactMap(\.mealType))
        let shouldDistributeWholeDay = mentionedMealTypes.isEmpty &&
            Self.looksLikeWholeDayList(trimmedText) &&
            aiMealTypes.count <= 1

        draftItems = items.enumerated().map { itemIndex, item in
            let mealType: MealType

            if shouldDistributeWholeDay {
                mealType = Self.inferredWholeDayMealType(for: item, index: itemIndex, totalCount: items.count)
            } else if mentionedMealTypes.count == 1 {
                mealType = fallbackMealType
            } else {
                mealType = item.mealType ?? fallbackMealType
            }

            return DraftFoodItem(
                name: item.name,
                quantityDescription: item.quantityDescription,
                mealType: mealType,
                estimatedWeightGrams: item.estimatedWeightGrams,
                caloriesKcal: item.caloriesKcal,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG
            )
        }
    }

    private func saveEntries() {
        guard !draftItems.isEmpty else { return }
        let createdAt = Date()

        for (index, item) in draftItems.enumerated() {
            let analysis = FoodEntry.Analysis(
                foodName: item.name,
                caloriesKcal: item.caloriesKcal,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                confidence: analysisResult?.analysis.confidence,
                assumptions: nil,
                items: []
            )

            let entry = FoodEntry(
                id: UUID(),
                createdAt: createdAt.addingTimeInterval(Double(index) * 0.1),
                consumptionDate: consumptionTimestamp(for: item.mealType, offsetMinutes: index),
                mealType: item.mealType,
                photoFileName: nil,
                userText: trimmedText.isEmpty ? nil : trimmedText,
                weightGrams: item.estimatedWeightGrams,
                portionDescription: item.quantityDescription,
                analysis: analysis
            )

            store.addEntry(entry)
        }

        dismiss()
    }

    private func removeDraftItem(id: UUID) {
        draftItems.removeAll { $0.id == id }
    }

    private func appendToken(_ token: String) {
        let separator = trimmedText.isEmpty ? "" : " "
        dictatedText = "\(trimmedText)\(separator)\(token)"
    }

    private func analysisContextDate() -> Date {
        let inferredMealType = MealType.inferred(fromText: trimmedText)
            ?? MealType.inferredFromClock(Date())
        return analysisContextDate(for: inferredMealType)
    }

    private func analysisContextDate(for mealType: MealType) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return Date()
        }
        return calendar.date(bySettingHour: mealType.defaultHour, minute: 0, second: 0, of: day) ?? day
    }

    private func consumptionTimestamp(for mealType: MealType, offsetMinutes: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(
            bySettingHour: mealType.defaultHour,
            minute: 0,
            second: 0,
            of: day
        ) ?? day
        return calendar.date(byAdding: .minute, value: offsetMinutes, to: base) ?? base
    }

    private static func looksLikeWholeDayList(_ text: String) -> Bool {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("за день") ||
            normalized.contains("весь день") ||
            normalized.contains("на весь день") {
            return true
        }

        let meaningfulLines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let bulletSeparators = normalized.filter { "*•-".contains($0) }.count
        let listSeparators = normalized.filter { ",;+".contains($0) }.count

        return meaningfulLines.count >= 5 || bulletSeparators >= 4 || listSeparators >= 8
    }

    private static func inferredWholeDayMealType(
        for item: FoodEntry.Analysis.ItemBreakdown,
        index: Int,
        totalCount: Int
    ) -> MealType {
        let normalized = "\(item.name) \(item.quantityDescription)"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let progress = Double(index) / Double(max(totalCount - 1, 1))

        if containsAny(normalized, ["кофе", "coffee", "сырник", "овсян", "каша", "яиц", "яйц", "омлет"]) {
            return .breakfast
        }

        if containsAny(normalized, ["skyr", "скайр", "скир", "quark", "кварк", "йогурт", "протеин", "яблок", "банан", "палоч"]) {
            return progress < 0.45 ? .secondBreakfast : .afternoonSnack
        }

        if containsAny(normalized, ["творог", "cottage"]) {
            return progress > 0.65 ? .lateSnack : .secondBreakfast
        }

        if containsAny(normalized, ["лаваш", "тунец", "рыб", "котлет", "филе", "кур", "индей", "говяд", "мяс"]) {
            return progress < 0.58 ? .lunch : .dinner
        }

        if containsAny(normalized, ["овощ", "салат", "лютениц", "соус"]) {
            return progress < 0.58 ? .lunch : .dinner
        }

        switch progress {
        case ..<0.18:
            return .breakfast
        case ..<0.42:
            return .lunch
        case ..<0.62:
            return .afternoonSnack
        case ..<0.86:
            return .dinner
        default:
            return .lateSnack
        }
    }

    private static func containsAny(_ text: String, _ tokens: [String]) -> Bool {
        tokens.contains { text.contains($0) }
    }

    private static func parsedMealSections(from text: String) -> [ParsedMealSection] {
        let lines = text.components(separatedBy: .newlines)
        var rawSections: [RawMealSection] = []
        var currentMarker: SectionMarker?
        var currentTitle = ""
        var currentLines: [String] = []

        func flushSection() {
            guard let currentMarker else { return }
            let body = currentLines
                .map { cleanedFoodLine($0) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !body.isEmpty else {
                currentLines.removeAll()
                return
            }

            rawSections.append(
                RawMealSection(
                    marker: currentMarker,
                    title: currentTitle,
                    body: body
                )
            )
            currentLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !isDividerLine(trimmed) else { continue }

            if let marker = sectionMarker(for: trimmed) {
                flushSection()
                currentMarker = marker
                currentTitle = cleanedSectionTitle(trimmed)
            } else if currentMarker != nil {
                currentLines.append(trimmed)
            }
        }

        flushSection()

        guard rawSections.count >= 2 else { return [] }

        return rawSections.enumerated().map { index, section in
            let mealType = resolvedMealType(for: section.marker, at: index, in: rawSections)
            return ParsedMealSection(
                mealType: mealType,
                title: section.title,
                body: section.body
            )
        }
    }

    private static func sectionMarker(for line: String) -> SectionMarker? {
        let title = cleanedSectionTitle(line)
        guard !title.isEmpty else { return nil }

        let normalized = title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        guard normalized.count <= 42,
              !normalized.contains(" ккал"),
              !normalized.contains(" кал"),
              !normalized.contains(" г "),
              !normalized.hasSuffix(" г") else {
            return nil
        }

        if normalized.contains("второй завтрак") {
            return .fixed(.secondBreakfast)
        }
        if normalized.contains("завтрак") {
            return .fixed(.breakfast)
        }
        if normalized.contains("обед") || normalized.contains("ланч") {
            return .fixed(.lunch)
        }
        if normalized.contains("полдник") {
            return .fixed(.afternoonSnack)
        }
        if normalized.contains("ужин") {
            return .fixed(.dinner)
        }
        if normalized.contains("перекус") || normalized.contains("снек") {
            return .floatingSnack
        }
        if normalized.contains("дополнительно") || normalized == "еще" || normalized == "ещё" {
            return .additional
        }

        return nil
    }

    private static func resolvedMealType(
        for marker: SectionMarker,
        at index: Int,
        in sections: [RawMealSection]
    ) -> MealType {
        if case .fixed(let mealType) = marker {
            return mealType
        }

        let previousFixed = (0..<index).reversed()
            .compactMap { fixedMealType(from: sections[$0].marker) }
            .first
        let nextFixed = ((index + 1)..<sections.count)
            .compactMap { fixedMealType(from: sections[$0].marker) }
            .first

        switch (previousFixed, nextFixed) {
        case (.breakfast?, .lunch?):
            return .secondBreakfast
        case (.breakfast?, .dinner?):
            return .afternoonSnack
        case (.lunch?, .dinner?):
            return .afternoonSnack
        case (.dinner?, _):
            return .lateSnack
        case (_, .breakfast?):
            return .lateSnack
        case (_, .lunch?):
            return .secondBreakfast
        case (_, .dinner?):
            return .afternoonSnack
        default:
            return marker == .additional ? .afternoonSnack : .lateSnack
        }
    }

    private static func fixedMealType(from marker: SectionMarker) -> MealType? {
        guard case .fixed(let mealType) = marker else { return nil }
        return mealType
    }

    private static func cleanedSectionTitle(_ line: String) -> String {
        line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*•-–—:|/\\"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanedFoodLine(_ line: String) -> String {
        line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "*•-–—"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isDividerLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { char in
            char == "-" || char == "—" || char == "–" || char == "⸻" || char.isWhitespace
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static let quickTokens = ["Skyr", "лютеница", "протеин", "без масла"]

    private static let speechContextualStrings = [
        "Skyr",
        "скайр",
        "скир",
        "йогурт Skyr",
        "банка Skyr",
        "лютеница",
        "протеин",
        "творог",
        "куриные котлеты",
        "без масла"
    ]
}

private struct DraftFoodItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var quantityDescription: String
    var mealType: MealType
    var estimatedWeightGrams: Double?
    var caloriesKcal: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
}

private struct MacroTotals {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var weight: Double = 0
}

private enum SectionMarker: Equatable {
    case fixed(MealType)
    case floatingSnack
    case additional
}

private struct RawMealSection {
    var marker: SectionMarker
    var title: String
    var body: String
}

private struct ParsedMealSection {
    var mealType: MealType
    var title: String
    var body: String

    var analysisText: String {
        """
        \(mealType.title): \(title)
        \(body)
        """
    }
}
