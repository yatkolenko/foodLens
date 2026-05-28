import SwiftUI
import UIKit

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FoodStore
    @StateObject private var speechTranscriber = SpeechTranscriber()

    private let originalEntry: FoodEntry?
    @State private var mealType: MealType
    @State private var mealDay: Date

    @State private var selectedImage: UIImage?
    @State private var showingCameraPicker = false
    @State private var showingLibraryPicker = false
    @State private var showingPhotoOptions = false
    @State private var didChangePhoto = false

    @State private var userText: String = ""
    @State private var weightGramsText: String = ""
    @State private var portionDescription: String = ""

    @State private var isAnalyzing = false
    @State private var analysisConfidence: Double?
    @State private var analysisAssumptions: String?
    @State private var analysisItems: [FoodEntry.Analysis.ItemBreakdown]
    @State private var editableFoodName = ""
    @State private var editableCaloriesText = ""
    @State private var editableProteinText = ""
    @State private var editableCarbsText = ""
    @State private var editableFatText = ""
    @State private var hasAnalysisResult = false
    @State private var errorMessage: String?
    @State private var dictationSeedText = ""
    @State private var showingDeleteConfirmation = false

    init(day: Date, mealType: MealType, entry: FoodEntry? = nil) {
        self.originalEntry = entry
        _mealType = State(initialValue: entry?.mealType ?? mealType)
        _mealDay = State(initialValue: (entry?.consumptionDate ?? day).startOfDay)
        _selectedImage = State(initialValue: Self.loadPhoto(named: entry?.photoFileName))
        _userText = State(initialValue: Self.initialUserText(for: entry))
        _weightGramsText = State(initialValue: entry?.weightGrams.map(Self.formattedNumber) ?? "")
        _portionDescription = State(initialValue: entry?.portionDescription ?? "")
        _analysisConfidence = State(initialValue: entry?.analysis.confidence)
        _analysisAssumptions = State(initialValue: entry?.analysis.assumptions)
        _analysisItems = State(initialValue: entry?.analysis.items ?? [])
        _editableFoodName = State(initialValue: entry?.analysis.foodName ?? "")
        _editableCaloriesText = State(initialValue: entry.map { Self.formattedNumber($0.analysis.caloriesKcal) } ?? "")
        _editableProteinText = State(initialValue: entry.map { Self.formattedNumber($0.analysis.proteinG) } ?? "")
        _editableCarbsText = State(initialValue: entry.map { Self.formattedNumber($0.analysis.carbsG) } ?? "")
        _editableFatText = State(initialValue: entry.map { Self.formattedNumber($0.analysis.fatG) } ?? "")
        _hasAnalysisResult = State(initialValue: entry != nil)
    }

    private var hasTextInput: Bool {
        !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !portionDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var normalizedAnalysisUserText: String? {
        let trimmedUserText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUserText.isEmpty {
            return trimmedUserText
        }

        let fallbackText = editableFoodName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallbackText.isEmpty ? nil : fallbackText
    }

    private var normalizedPortionDescription: String? {
        let trimmedPortionDescription = portionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPortionDescription.isEmpty ? nil : trimmedPortionDescription
    }

    private var canAnalyze: Bool {
        !isAnalyzing && (selectedImage != nil || normalizedAnalysisUserText != nil || normalizedPortionDescription != nil)
    }

    private var canStartManualEntry: Bool {
        !isAnalyzing
    }

    private var canUseVoiceInput: Bool {
        !isAnalyzing && speechTranscriber.isSupported && speechTranscriber.isRecognizerAvailable
    }

    private var canSaveEditedResult: Bool {
        !editableFoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedNumber(editableCaloriesText) != nil &&
        parsedNumber(editableProteinText) != nil &&
        parsedNumber(editableCarbsText) != nil &&
        parsedNumber(editableFatText) != nil
    }

    private var analysisButtonTitle: String {
        switch (selectedImage != nil, normalizedAnalysisUserText != nil || normalizedPortionDescription != nil) {
        case (true, true):
            return "Проанализировать фото и описание"
        case (true, false):
            return "Проанализировать фото"
        case (false, true):
            return "Проанализировать описание"
        default:
            return "Проанализировать"
        }
    }

    private var screenTitle: String {
        isEditing ? "Редактировать запись" : "Новая запись"
    }

    private var saveButtonTitle: String {
        isEditing ? "Сохранить изменения" : "Сохранить в дневник"
    }

    private var isEditing: Bool {
        originalEntry != nil
    }

    private var mealDayBinding: Binding<Date> {
        Binding(
            get: { mealDay },
            set: { mealDay = $0.startOfDay }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                mealMetaCard
                mealComposerCard

                if hasAnalysisResult {
                    resultEditorCard
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if canAnalyze {
                    Button {
                        analyze()
                    } label: {
                        if isAnalyzing {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(analysisButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canAnalyze)
                }

                if !hasAnalysisResult {
                    Button {
                        startManualEntry()
                    } label: {
                        Text("Заполнить вручную без распознавания")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canStartManualEntry)
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignTokens.background)
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Удалить запись")
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
            if hasAnalysisResult {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        saveEntry()
                    } label: {
                        Text(saveButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSaveEditedResult)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .confirmationDialog(
            "Удалить запись?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                deleteEntry()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Запись будет удалена из дневника за выбранный день.")
        }
        .fullScreenCover(isPresented: $showingCameraPicker) {
            ImagePickerSheet(image: $selectedImage, sourceType: .camera) {
                didChangePhoto = true
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingLibraryPicker) {
            ImagePickerSheet(image: $selectedImage, sourceType: .photoLibrary) {
                didChangePhoto = true
            }
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

    private var mealMetaCard: some View {
        CardView {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    metaIcon("calendar")

                    DatePicker(
                        "Дата",
                        selection: mealDayBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Divider()

                HStack(spacing: 12) {
                    metaIcon(mealType.systemImage)

                    Picker("Приём пищи", selection: $mealType) {
                        ForEach(MealType.rationOrder) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var mealComposerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Что съели")
                            .font(.headline)
                        Text(composerStatusText)
                            .font(.caption)
                            .foregroundStyle(speechTranscriber.isRecording ? DesignTokens.accentGreen : DesignTokens.textSecondary)
                    }

                    Spacer()

                    Button {
                        toggleDictation()
                    } label: {
                        Image(systemName: speechTranscriber.isRecording ? "stop.fill" : "mic.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(speechTranscriber.isRecording ? Color.red : DesignTokens.accentGreen)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUseVoiceInput && !speechTranscriber.isRecording)
                }

                FloatingLabelTextField(
                    title: "Описание блюда",
                    text: $userText,
                    axis: .vertical,
                    lineLimit: 4,
                    minHeight: 104
                )

                photoSection

                HStack(alignment: .top, spacing: 10) {
                    FloatingLabelTextField(
                        title: "Вес (г)",
                        text: $weightGramsText,
                        keyboardType: .decimalPad,
                        textInputAutocapitalization: .never,
                        autocorrectionDisabled: true
                    )

                    FloatingLabelTextField(
                        title: "Уточнение",
                        text: $portionDescription,
                        axis: .vertical,
                        lineLimit: 2,
                        minHeight: 60
                    )
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showingPhotoOptions {
                photoSourcePicker
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let selectedImage {
                photoPreview(selectedImage)
            }

            Button {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                    showingPhotoOptions.toggle()
                }
            } label: {
                Label(selectedImage == nil ? "Добавить фото" : "Заменить фото", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isAnalyzing)
        }
    }

    private var photoSourcePicker: some View {
        HStack(spacing: 10) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                sourceButton(title: "Камера", icon: "camera.fill") {
                    showingPhotoOptions = false
                    showingCameraPicker = true
                }
            }

            sourceButton(title: "Галерея", icon: "photo.on.rectangle.angled") {
                showingPhotoOptions = false
                showingLibraryPicker = true
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignTokens.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
        )
    }

    private func sourceButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DesignTokens.cardElevated)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignTokens.accentGreen)
    }

    private func photoPreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(role: .destructive) {
                selectedImage = nil
                showingPhotoOptions = false
                didChangePhoto = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .padding(10)
        }
    }

    private func metaIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .foregroundStyle(DesignTokens.accentGreen)
            .frame(width: 28)
    }

    private var composerStatusText: String {
        if speechTranscriber.isRecording {
            return "Говорите свободно"
        }
        if selectedImage != nil && hasTextInput {
            return "Фото и описание"
        }
        if selectedImage != nil {
            return "Фото готово"
        }
        if hasTextInput {
            return "Описание готово"
        }
        return "Описание, фото или оба варианта"
    }

    private var voiceInputHint: String {
        if speechTranscriber.isRecording {
            return "Идёт диктовка. Говорите свободно, текст будет подставляться в описание."
        }

        if !speechTranscriber.isSupported {
            return "Системная диктовка недоступна на этом устройстве."
        }

        if !speechTranscriber.isRecognizerAvailable {
            return "Системное распознавание речи сейчас недоступно."
        }

        return "Можно не печатать вручную: нажмите на микрофон и надиктуйте состав блюда."
    }

    private var resultEditorCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Данные блюда")
                    .font(.headline)
                Text(editorHelperText)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)

                FloatingLabelTextField(
                    title: "Название блюда",
                    text: $editableFoodName
                )

                FloatingLabelTextField(
                    title: "Калории (ккал)",
                    text: $editableCaloriesText,
                    keyboardType: .decimalPad,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true
                )

                FloatingLabelTextField(
                    title: "Белки (г)",
                    text: $editableProteinText,
                    keyboardType: .decimalPad,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true
                )

                FloatingLabelTextField(
                    title: "Углеводы (г)",
                    text: $editableCarbsText,
                    keyboardType: .decimalPad,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true
                )

                FloatingLabelTextField(
                    title: "Жиры (г)",
                    text: $editableFatText,
                    keyboardType: .decimalPad,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true
                )

                if let analysisConfidence {
                    Text("Уверенность распознавания: \(Int(analysisConfidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let analysisAssumptions, !analysisAssumptions.isEmpty {
                    Text(analysisAssumptions)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                if !analysisItems.isEmpty {
                    Divider().padding(.top, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Разбивка по продуктам")
                            .font(.subheadline.weight(.semibold))

                        ForEach(analysisItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(item.quantityDescription)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DesignTokens.accentGreen)
                                }

                                Text(
                                    "\(integerLikeString(item.caloriesKcal)) ккал · Б \(integerLikeString(item.proteinG)) · У \(integerLikeString(item.carbsG)) · Ж \(integerLikeString(item.fatG))"
                                )
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                            }

                            if item.id != analysisItems.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var editorHelperText: String {
        if analysisConfidence != nil || analysisAssumptions != nil {
            return "Распознавание заполнило значения автоматически. При необходимости вы можете поправить их вручную перед сохранением."
        }

        return "Заполните данные блюда вручную и сохраните запись без распознавания."
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

                Text("Анализируем блюдо")
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

    private func consumptionTimestamp() -> Date {
        let cal = Calendar.current
        if let originalEntry,
           cal.isDate(originalEntry.consumptionDate, inSameDayAs: mealDay),
           originalEntry.mealType == mealType {
            return originalEntry.consumptionDate
        }
        return cal.date(bySettingHour: mealType.defaultHour, minute: 0, second: 0, of: mealDay.startOfDay) ?? mealDay.startOfDay
    }

    private func analyze() {
        errorMessage = nil

        guard selectedImage != nil || hasTextInput else {
            errorMessage = "Добавьте фото, описание блюда или оба варианта вместе."
            return
        }

        Task {
            isAnalyzing = true
            defer { isAnalyzing = false }

            do {
                let result = try await AIClient.shared.analyzeFood(
                    image: selectedImage,
                    userText: normalizedAnalysisUserText,
                    weightGrams: parsedNumber(weightGramsText),
                    portionDescription: normalizedPortionDescription,
                    mealContextDate: consumptionTimestamp()
                )

                applyAnalysisResult(result)
            } catch let error as AIClient.AIClientError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Ошибка сети."
            }
        }
    }

    private func startManualEntry() {
        errorMessage = nil
        hasAnalysisResult = true

        if editableFoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editableFoodName = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func toggleDictation() {
        if speechTranscriber.isRecording {
            speechTranscriber.stopTranscribing()
            return
        }

        dictationSeedText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil

        Task {
            do {
                try await speechTranscriber.startTranscribing()
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
            userText = trimmedTranscript
        } else {
            userText = "\(dictationSeedText) \(trimmedTranscript)"
        }
    }

    private func applyAnalysisResult(_ result: AIClient.MealAnalysisResult) {
        editableFoodName = result.analysis.foodName
        editableCaloriesText = integerLikeString(result.analysis.caloriesKcal)
        editableProteinText = integerLikeString(result.analysis.proteinG)
        editableCarbsText = integerLikeString(result.analysis.carbsG)
        editableFatText = integerLikeString(result.analysis.fatG)
        analysisConfidence = result.analysis.confidence
        analysisAssumptions = result.analysis.assumptions
        analysisItems = result.analysis.items
        hasAnalysisResult = true

        if weightGramsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let estimatedWeight = result.estimatedWeightGrams {
            weightGramsText = integerLikeString(estimatedWeight)
        }
    }

    private func saveEntry() {
        guard canSaveEditedResult,
              let calories = parsedNumber(editableCaloriesText),
              let protein = parsedNumber(editableProteinText),
              let carbs = parsedNumber(editableCarbsText),
              let fat = parsedNumber(editableFatText) else {
            errorMessage = "Проверьте, что название и БЖУ заполнены корректно."
            return
        }

        let analysis = FoodEntry.Analysis(
            foodName: editableFoodName.trimmingCharacters(in: .whitespacesAndNewlines),
            caloriesKcal: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            confidence: analysisConfidence,
            assumptions: analysisAssumptions,
            items: analysisItems
        )

        let entry = FoodEntry(
            id: originalEntry?.id ?? UUID(),
            createdAt: originalEntry?.createdAt ?? Date(),
            consumptionDate: consumptionTimestamp(),
            mealType: mealType,
            photoFileName: persistedPhotoFileName(),
            userText: userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userText,
            weightGrams: parsedNumber(weightGramsText),
            portionDescription: portionDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : portionDescription,
            analysis: analysis
        )

        if isEditing {
            store.updateEntry(entry)
        } else {
            store.addEntry(entry)
        }
        dismiss()
    }

    private func deleteEntry() {
        guard let originalEntry else { return }
        store.deleteEntry(id: originalEntry.id)
        dismiss()
    }

    private func persistedPhotoFileName() -> String? {
        guard isEditing else {
            return savePhoto(selectedImage)
        }

        if didChangePhoto {
            let newPhotoFileName = savePhoto(selectedImage)
            if let oldPhotoFileName = originalEntry?.photoFileName,
               oldPhotoFileName != newPhotoFileName {
                deletePhoto(named: oldPhotoFileName)
            }
            return newPhotoFileName
        }

        return originalEntry?.photoFileName
    }

    private func savePhoto(_ image: UIImage?) -> String? {
        guard let image else { return nil }
        let fm = FileManager.default
        let dir = Self.photosDirectoryURL(fileManager: fm)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        try? data.write(to: url, options: [.atomic])
        return name
    }

    private func deletePhoto(named fileName: String) {
        let fm = FileManager.default
        let url = Self.photosDirectoryURL(fileManager: fm).appendingPathComponent(fileName)
        try? fm.removeItem(at: url)
    }

    private func parsedNumber(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func integerLikeString(_ value: Double) -> String {
        Self.formattedNumber(value)
    }

    nonisolated private static func formattedNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    nonisolated private static func initialUserText(for entry: FoodEntry?) -> String {
        if let text = entry?.userText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        return entry?.analysis.foodName ?? ""
    }

    nonisolated private static func loadPhoto(named fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        let url = photosDirectoryURL(fileManager: FileManager.default).appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    nonisolated private static func photosDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("FoodLens/Photos", isDirectory: true)
    }
}

private struct ImagePickerSheet: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    var onImagePicked: () -> Void = {}

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.modalPresentationStyle = .fullScreen
        picker.allowsEditing = false
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerSheet

        init(_ parent: ImagePickerSheet) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.onImagePicked()
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
