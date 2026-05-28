import Combine
import Foundation

@MainActor
final class FoodStore: ObservableObject {
    struct ImportReport {
        var addedEntries: Int
        var skippedEntries: Int
        var addedWeightLogs: Int
        var skippedWeightLogs: Int
        var updatedWaterDays: Int
    }

    @Published private(set) var profile: UserProfile?
    @Published private(set) var entries: [FoodEntry] = []
    @Published private(set) var appSettings: AppSettings
    @Published private(set) var weightLogs: [WeightLogEntry] = []
    @Published private(set) var waterLitersByDay: [String: Double] = [:]
    @Published private(set) var nutritionAdviceByDay: [String: DailyNutritionAdvice] = [:]

    private let profileURL: URL
    private let entriesURL: URL
    private let settingsURL: URL
    private let weightsURL: URL
    private let waterURL: URL
    private let nutritionAdviceURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("FoodLens", isDirectory: true)
        self.profileURL = directory.appendingPathComponent("profile.json")
        self.entriesURL = directory.appendingPathComponent("entries.json")
        self.settingsURL = directory.appendingPathComponent("app_settings.json")
        self.weightsURL = directory.appendingPathComponent("weight_logs.json")
        self.waterURL = directory.appendingPathComponent("water_by_day.json")
        self.nutritionAdviceURL = directory.appendingPathComponent("nutrition_advice_by_day.json")

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        self.appSettings = AppSettings(onboardingCompleted: false)
        loadFromDisk()
    }

    var onboardingCompleted: Bool {
        appSettings.onboardingCompleted
    }

    func completeOnboarding() {
        appSettings = AppSettings(onboardingCompleted: true)
        saveSettingsToDisk()
    }

    /// Для отладки / смены аккаунта.
    func resetOnboardingFlow() {
        appSettings = AppSettings(onboardingCompleted: false)
        saveSettingsToDisk()
    }

    func upsertProfile(_ newProfile: UserProfile) {
        self.profile = newProfile
        saveProfileToDisk()
    }

    func addEntry(_ entry: FoodEntry) {
        entries.append(entry)
        entries.sort { $0.consumptionDate < $1.consumptionDate }
        saveEntriesToDisk()
    }

    func updateEntry(_ updatedEntry: FoodEntry) {
        if let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) {
            entries[index] = updatedEntry
            entries.sort { $0.consumptionDate < $1.consumptionDate }
        } else {
            entries.append(updatedEntry)
            entries.sort { $0.consumptionDate < $1.consumptionDate }
        }
        saveEntriesToDisk()
    }

    func deleteEntry(id: UUID) {
        if let photoFileName = entries.first(where: { $0.id == id })?.photoFileName {
            let photoURL = Self.photosDirectoryURL(fileManager: FileManager.default).appendingPathComponent(photoFileName)
            try? FileManager.default.removeItem(at: photoURL)
        }
        entries.removeAll { $0.id == id }
        saveEntriesToDisk()
    }

    func importLegacyPayload(_ payload: LegacyImportService.ImportPayload) -> ImportReport {
        var existingEntryKeys = Set(entries.map(entryImportKey))
        var existingWeightKeys = Set(weightLogs.map(weightImportKey))

        var addedEntries = 0
        var skippedEntries = 0
        var addedWeightLogs = 0
        var skippedWeightLogs = 0
        var updatedWaterDays = 0

        for entry in payload.entries {
            let key = entryImportKey(entry)
            if existingEntryKeys.contains(key) {
                skippedEntries += 1
                continue
            }

            entries.append(entry)
            existingEntryKeys.insert(key)
            addedEntries += 1
        }

        for log in payload.weightLogs {
            let key = weightImportKey(log)
            if existingWeightKeys.contains(key) {
                skippedWeightLogs += 1
                continue
            }

            weightLogs.append(log)
            existingWeightKeys.insert(key)
            addedWeightLogs += 1
        }

        for (dayKey, liters) in payload.waterByDay {
            if waterLitersByDay[dayKey] != liters {
                waterLitersByDay[dayKey] = liters
                updatedWaterDays += 1
            }
        }

        entries.sort { $0.consumptionDate < $1.consumptionDate }
        weightLogs.sort { $0.date < $1.date }

        if addedEntries > 0 || skippedEntries > 0 {
            saveEntriesToDisk()
        }
        if addedWeightLogs > 0 || skippedWeightLogs > 0 {
            saveWeightsToDisk()
        }
        if updatedWaterDays > 0 {
            saveWaterToDisk()
        }

        return ImportReport(
            addedEntries: addedEntries,
            skippedEntries: skippedEntries,
            addedWeightLogs: addedWeightLogs,
            skippedWeightLogs: skippedWeightLogs,
            updatedWaterDays: updatedWaterDays
        )
    }

    func entries(for day: Date) -> [FoodEntry] {
        let start = day.startOfDay
        let next = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return entries
            .filter { $0.consumptionDate >= start && $0.consumptionDate < next }
            .sorted(by: { $0.consumptionDate < $1.consumptionDate })
    }

    func entries(for day: Date, meal: MealType) -> [FoodEntry] {
        entries(for: day).filter { $0.mealType == meal }
    }

    func totals(for day: Date) -> (kcal: Double, protein: Double, carbs: Double, fat: Double) {
        let list = entries(for: day)
        let kcal = list.reduce(0) { $0 + $1.analysis.caloriesKcal }
        let p = list.reduce(0) { $0 + $1.analysis.proteinG }
        let c = list.reduce(0) { $0 + $1.analysis.carbsG }
        let f = list.reduce(0) { $0 + $1.analysis.fatG }
        return (kcal, p, c, f)
    }

    func waterLiters(on day: Date) -> Double {
        let key = Calendar.current.dayKey(for: day)
        return waterLitersByDay[key] ?? 0
    }

    func setWaterLiters(_ value: Double, on day: Date) {
        let key = Calendar.current.dayKey(for: day)
        if value <= 0 {
            waterLitersByDay.removeValue(forKey: key)
        } else {
            waterLitersByDay[key] = value
        }
        saveWaterToDisk()
    }

    func addWater(_ delta: Double, on day: Date) {
        let current = waterLiters(on: day)
        setWaterLiters(max(0, current + delta), on: day)
    }

    func nutritionAdvice(on day: Date) -> DailyNutritionAdvice? {
        nutritionAdviceByDay[Calendar.current.dayKey(for: day)]
    }

    func upsertNutritionAdvice(_ advice: DailyNutritionAdvice) {
        nutritionAdviceByDay[advice.dayKey] = advice
        saveNutritionAdviceToDisk()
    }

    func addWeightLog(weightKg: Double, date: Date = Date()) {
        let entry = WeightLogEntry(id: UUID(), date: date, weightKg: weightKg)
        weightLogs.append(entry)
        weightLogs.sort { $0.date < $1.date }
        saveWeightsToDisk()
    }

    func deleteWeightLog(id: UUID) {
        weightLogs.removeAll { $0.id == id }
        saveWeightsToDisk()
    }

    func sortedWeightLogs() -> [WeightLogEntry] {
        weightLogs.sorted { $0.date < $1.date }
    }

    /// Полный сброс локальных данных (профиль, дневник, вес, вода).
    func resetAllUserData() {
        profile = nil
        entries = []
        weightLogs = []
        waterLitersByDay = [:]
        appSettings = AppSettings(onboardingCompleted: false)

        try? FileManager.default.removeItem(at: profileURL)
        try? FileManager.default.removeItem(at: entriesURL)
        try? FileManager.default.removeItem(at: weightsURL)
        try? FileManager.default.removeItem(at: waterURL)
        try? FileManager.default.removeItem(at: nutritionAdviceURL)
        saveSettingsToDisk()
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? decoder.decode(AppSettings.self, from: data) {
            self.appSettings = decoded
        }

        if let data = try? Data(contentsOf: profileURL),
           let decoded = try? decoder.decode(UserProfile.self, from: data) {
            self.profile = decoded
        }

        if let data = try? Data(contentsOf: entriesURL),
           let decoded = try? decoder.decode([FoodEntry].self, from: data) {
            self.entries = decoded
        }

        if let data = try? Data(contentsOf: weightsURL),
           let decoded = try? decoder.decode([WeightLogEntry].self, from: data) {
            self.weightLogs = decoded.sorted { $0.date < $1.date }
        }

        if let data = try? Data(contentsOf: waterURL),
           let decoded = try? decoder.decode([String: Double].self, from: data) {
            self.waterLitersByDay = decoded
        }

        if let data = try? Data(contentsOf: nutritionAdviceURL),
           let decoded = try? decoder.decode([String: DailyNutritionAdvice].self, from: data) {
            self.nutritionAdviceByDay = decoded
        }

        // Миграция: был профиль без флага онбординга.
        if profile != nil, !appSettings.onboardingCompleted {
            appSettings = AppSettings(onboardingCompleted: true)
            saveSettingsToDisk()
        }
    }

    private func saveSettingsToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(appSettings) {
            try? data.write(to: settingsURL, options: [.atomic])
        }
    }

    private func saveProfileToDisk() {
        guard let profile else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(profile) {
            try? data.write(to: profileURL, options: [.atomic])
        }
    }

    private func saveEntriesToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(entries) {
            try? data.write(to: entriesURL, options: [.atomic])
        }
    }

    private func saveWeightsToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(weightLogs) {
            try? data.write(to: weightsURL, options: [.atomic])
        }
    }

    private func saveWaterToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(waterLitersByDay) {
            try? data.write(to: waterURL, options: [.atomic])
        }
    }

    private func saveNutritionAdviceToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(nutritionAdviceByDay) {
            try? data.write(to: nutritionAdviceURL, options: [.atomic])
        }
    }

    private func entryImportKey(_ entry: FoodEntry) -> String {
        let formatter = ISO8601DateFormatter()
        let date = formatter.string(from: entry.consumptionDate)
        let name = entry.analysis.foodName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let notes = (entry.userText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let weight = entry.weightGrams.map { String(format: "%.1f", $0) } ?? "-"

        return [
            date,
            entry.mealType.rawValue,
            name,
            String(format: "%.1f", entry.analysis.caloriesKcal),
            String(format: "%.1f", entry.analysis.proteinG),
            String(format: "%.1f", entry.analysis.carbsG),
            String(format: "%.1f", entry.analysis.fatG),
            weight,
            notes
        ].joined(separator: "|")
    }

    private func weightImportKey(_ log: WeightLogEntry) -> String {
        [
            Calendar.current.dayKey(for: log.date),
            String(format: "%.1f", log.weightKg)
        ].joined(separator: "|")
    }

    private static func photosDirectoryURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("FoodLens/Photos", isDirectory: true)
    }
}
