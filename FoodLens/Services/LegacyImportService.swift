import Foundation

@MainActor
enum LegacyImportService {
    struct ImportPayload {
        var sourceApp: String?
        var entries: [FoodEntry]
        var weightLogs: [WeightLogEntry]
        var waterByDay: [String: Double]
    }

    enum ImportError: LocalizedError {
        case invalidFileFormat
        case invalidJSON
        case invalidCSV
        case invalidCSVRow(Int, String)
        case emptyPayload
        case invalidEntry(Int, String)
        case invalidWeight(Int, String)
        case invalidWater(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidFileFormat:
                return "Файл не похож ни на корректный CSV, ни на поддерживаемый JSON."
            case .invalidJSON:
                return "Файл не похож на корректный JSON в ожидаемом формате."
            case .invalidCSV:
                return "Файл не похож на корректный CSV в ожидаемом формате."
            case .invalidCSVRow(let index, let message):
                return "Ошибка в строке CSV \(index): \(message)"
            case .emptyPayload:
                return "В файле нет данных для импорта. Нужны хотя бы записи питания, веса или воды."
            case .invalidEntry(let index, let message):
                return "Ошибка в entries[\(index)]: \(message)"
            case .invalidWeight(let index, let message):
                return "Ошибка в weightLogs[\(index)]: \(message)"
            case .invalidWater(let index, let message):
                return "Ошибка в waterLogs[\(index)]: \(message)"
            }
        }
    }

    static let aiChatPrompt: String = """
    У меня есть скриншоты из приложения для питания. Извлеки из них данные и создай CSV-файл для скачивания.
    Не пиши пояснений в сообщении и не используй markdown. Верни только готовый CSV-файл.

    Используй CSV с таким заголовком:
    recordType,date,time,mealType,foodName,caloriesKcal,proteinG,carbsG,fatG,weightGrams,weightKg,waterLiters,notes

    Правила:
    1. Для строк с едой используй recordType=entry.
    2. Для строк с весом используй recordType=weight.
    3. Для строк с водой используй recordType=water.
    4. Для entry обязательно постарайся вернуть: date, foodName, caloriesKcal.
    5. Поля time, mealType, proteinG, carbsG, fatG, weightGrams и notes можно оставлять пустыми, если их нет на скриншоте.
    6. Вода и история веса не обязательны. Если их нет, просто не добавляй такие строки.
    7. mealType используй как breakfast, snack, lunch или dinner.
    8. Если внутри текста есть запятые, заключай поле в обычные двойные кавычки.
    9. Все числа должны быть обычными числами без единиц измерения.
    """

    static let exampleCSV: String = """
    recordType,date,time,mealType,foodName,caloriesKcal,proteinG,carbsG,fatG,weightGrams,weightKg,waterLiters,notes
    entry,2026-03-14,08:30,breakfast,"1 сырник, 4 вареных яйца, 2 черных кофе",520,32,,,310,,,"Импорт со скриншота"
    entry,2026-03-14,,lunch,"Курица с рисом",640,,,,,,,
    weight,2026-03-14,,,,,,,,,85.5,,
    water,2026-03-14,,,,,,,,,,2.25,
    """

    static func parse(data: Data, fileExtension: String? = nil) throws -> ImportPayload {
        let normalizedString = normalizedText(from: data)
        let trimmed = normalizedString.trimmingCharacters(in: .whitespacesAndNewlines)
        let ext = fileExtension?.lowercased()

        if ext == "csv" || looksLikeCSV(trimmed) {
            return try parseCSV(string: trimmed)
        }

        if ext == "json" || trimmed.first == "{" || trimmed.first == "[" {
            return try parseJSON(string: trimmed)
        }

        if let payload = try? parseCSV(string: trimmed) {
            return payload
        }

        if let payload = try? parseJSON(string: trimmed) {
            return payload
        }

        throw ImportError.invalidFileFormat
    }

    static func exportCSV(entries: [FoodEntry], weightLogs: [WeightLogEntry], waterByDay: [String: Double]) -> String {
        var rows = [[String]]()
        rows.append([
            "recordType",
            "date",
            "time",
            "mealType",
            "foodName",
            "caloriesKcal",
            "proteinG",
            "carbsG",
            "fatG",
            "weightGrams",
            "weightKg",
            "waterLiters",
            "notes"
        ])

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.dateFormat = "HH:mm"

        for entry in entries.sorted(by: { $0.consumptionDate < $1.consumptionDate }) {
            rows.append([
                "entry",
                dayFormatter.string(from: entry.consumptionDate),
                timeFormatter.string(from: entry.consumptionDate),
                exportMealType(entry.mealType),
                entry.analysis.foodName,
                exportNumber(entry.analysis.caloriesKcal),
                exportNumber(entry.analysis.proteinG),
                exportNumber(entry.analysis.carbsG),
                exportNumber(entry.analysis.fatG),
                entry.weightGrams.map(exportNumber) ?? "",
                "",
                "",
                exportNotes(for: entry)
            ])
        }

        for log in weightLogs.sorted(by: { $0.date < $1.date }) {
            rows.append([
                "weight",
                dayFormatter.string(from: log.date),
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                exportNumber(log.weightKg),
                "",
                ""
            ])
        }

        for (dayKey, liters) in waterByDay.sorted(by: { $0.key < $1.key }) {
            rows.append([
                "water",
                dayKey,
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                exportNumber(liters),
                ""
            ])
        }

        return rows
            .map { $0.map(csvEscaped).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func parseJSON(string: String) throws -> ImportPayload {
        guard let data = string.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }

        let decoder = JSONDecoder()

        let rawPayload: RawPayload
        do {
            rawPayload = try decoder.decode(RawPayload.self, from: data)
        } catch {
            throw ImportError.invalidJSON
        }

        let sourceApp = trimmedNilIfEmpty(rawPayload.sourceApp)

        let entries = try (rawPayload.entries ?? []).enumerated().map { index, raw in
            try buildEntry(from: raw, index: index, sourceApp: sourceApp)
        }

        let weightLogs = try (rawPayload.weightLogs ?? []).enumerated().map { index, raw in
            try buildWeightLog(from: raw, index: index)
        }

        let waterLogs = try (rawPayload.waterLogs ?? []).enumerated().reduce(into: [String: Double]()) { result, item in
            let (index, raw) = item
            let dayKeyAndLiters = try buildWaterLog(from: raw, index: index)
            result[dayKeyAndLiters.key] = dayKeyAndLiters.value
        }

        guard !entries.isEmpty || !weightLogs.isEmpty || !waterLogs.isEmpty else {
            throw ImportError.emptyPayload
        }

        return ImportPayload(
            sourceApp: sourceApp,
            entries: entries,
            weightLogs: weightLogs,
            waterByDay: waterLogs
        )
    }

    private static func parseCSV(string: String) throws -> ImportPayload {
        guard !string.isEmpty else {
            throw ImportError.invalidCSV
        }

        let delimiter = detectDelimiter(in: string)
        let rows = try parseCSVRows(from: string, delimiter: delimiter)
        guard let headerRow = rows.first else {
            throw ImportError.invalidCSV
        }

        let headers = headerRow.map(normalizedHeader)
        guard headers.contains("date") else {
            throw ImportError.invalidCSV
        }

        var entries: [FoodEntry] = []
        var weightLogs: [WeightLogEntry] = []
        var waterByDay: [String: Double] = [:]

        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            let mappedRow = dictionary(from: row, headers: headers)
            let recordType = inferredRecordType(for: mappedRow)

            switch recordType {
            case "entry":
                let entry = try buildEntry(fromCSV: mappedRow, rowNumber: rowNumber)
                entries.append(entry)
            case "weight":
                let weightLog = try buildWeightLog(fromCSV: mappedRow, rowNumber: rowNumber)
                weightLogs.append(weightLog)
            case "water":
                let water = try buildWaterLog(fromCSV: mappedRow, rowNumber: rowNumber)
                waterByDay[water.key] = water.value
            default:
                throw ImportError.invalidCSVRow(rowNumber, "recordType должен быть entry, weight или water.")
            }
        }

        guard !entries.isEmpty || !weightLogs.isEmpty || !waterByDay.isEmpty else {
            throw ImportError.emptyPayload
        }

        return ImportPayload(
            sourceApp: "AI chat",
            entries: entries,
            weightLogs: weightLogs,
            waterByDay: waterByDay
        )
    }

    private static func buildEntry(from raw: RawEntry, index: Int, sourceApp: String?) throws -> FoodEntry {
        let foodName = trimmedNilIfEmpty(raw.foodName)
        guard let foodName else {
            throw ImportError.invalidEntry(index, "foodName пустой.")
        }

        guard raw.caloriesKcal.value >= 0 else {
            throw ImportError.invalidEntry(index, "caloriesKcal не может быть отрицательным.")
        }
        if let protein = raw.proteinG?.value, protein < 0 {
            throw ImportError.invalidEntry(index, "proteinG не может быть отрицательным.")
        }
        if let carbs = raw.carbsG?.value, carbs < 0 {
            throw ImportError.invalidEntry(index, "carbsG не может быть отрицательным.")
        }
        if let fat = raw.fatG?.value, fat < 0 {
            throw ImportError.invalidEntry(index, "fatG не может быть отрицательным.")
        }
        if let weightGrams = raw.weightGrams, weightGrams.value <= 0 {
            throw ImportError.invalidEntry(index, "weightGrams должен быть больше 0, если указан.")
        }

        let consumptionDate = try parseEntryDate(raw.date, time: raw.time, index: index)
        let mealType = parseMealType(raw.mealType, fallbackDate: consumptionDate)

        let assumptions = trimmedNilIfEmpty(sourceApp).map { "Импортировано из \($0)" } ?? "Импортировано из другого приложения"

        return FoodEntry(
            id: UUID(),
            createdAt: Date(),
            consumptionDate: consumptionDate,
            mealType: mealType,
            photoFileName: nil,
            userText: trimmedNilIfEmpty(raw.notes),
            weightGrams: raw.weightGrams?.value,
            portionDescription: nil,
            analysis: FoodEntry.Analysis(
                foodName: foodName,
                caloriesKcal: raw.caloriesKcal.value,
                proteinG: raw.proteinG?.value ?? 0,
                carbsG: raw.carbsG?.value ?? 0,
                fatG: raw.fatG?.value ?? 0,
                confidence: nil,
                assumptions: assumptions
            )
        )
    }

    private static func buildWeightLog(from raw: RawWeightLog, index: Int) throws -> WeightLogEntry {
        guard raw.weightKg.value > 0 else {
            throw ImportError.invalidWeight(index, "weightKg должен быть больше 0.")
        }

        guard let date = parseDay(raw.date) else {
            throw ImportError.invalidWeight(index, "date должен быть в формате YYYY-MM-DD.")
        }

        return WeightLogEntry(
            id: UUID(),
            date: date.startOfDay,
            weightKg: raw.weightKg.value
        )
    }

    private static func buildWaterLog(from raw: RawWaterLog, index: Int) throws -> (key: String, value: Double) {
        guard raw.liters.value > 0 else {
            throw ImportError.invalidWater(index, "liters должен быть больше 0.")
        }

        guard let date = parseDay(raw.date) else {
            throw ImportError.invalidWater(index, "date должен быть в формате YYYY-MM-DD.")
        }

        return (Calendar.current.dayKey(for: date), raw.liters.value)
    }

    private static func buildEntry(fromCSV row: [String: String], rowNumber: Int) throws -> FoodEntry {
        guard let dateValue = field("date", in: row) else {
            throw ImportError.invalidCSVRow(rowNumber, "для entry обязательно поле date.")
        }
        guard let foodName = field("foodname", in: row) else {
            throw ImportError.invalidCSVRow(rowNumber, "для entry обязательно поле foodName.")
        }
        guard let calories = parseDouble(field("calorieskcal", in: row)) else {
            throw ImportError.invalidCSVRow(rowNumber, "для entry обязательно поле caloriesKcal.")
        }
        guard calories >= 0 else {
            throw ImportError.invalidCSVRow(rowNumber, "caloriesKcal не может быть отрицательным.")
        }

        let time = field("time", in: row)
        let consumptionDate = try parseEntryDate(dateValue, time: time, index: rowNumber)
        let mealType = parseMealType(field("mealtype", in: row), fallbackDate: consumptionDate)

        let protein = try validateMacro(field("proteing", in: row), name: "proteinG", rowNumber: rowNumber)
        let carbs = try validateMacro(field("carbsg", in: row), name: "carbsG", rowNumber: rowNumber)
        let fat = try validateMacro(field("fatg", in: row), name: "fatG", rowNumber: rowNumber)
        let weight = try validatePositiveOptional(field("weightgrams", in: row), name: "weightGrams", rowNumber: rowNumber)

        return FoodEntry(
            id: UUID(),
            createdAt: Date(),
            consumptionDate: consumptionDate,
            mealType: mealType,
            photoFileName: nil,
            userText: field("notes", in: row),
            weightGrams: weight,
            portionDescription: nil,
            analysis: FoodEntry.Analysis(
                foodName: foodName,
                caloriesKcal: calories,
                proteinG: protein ?? 0,
                carbsG: carbs ?? 0,
                fatG: fat ?? 0,
                confidence: nil,
                assumptions: "Импортировано из AI chat"
            )
        )
    }

    private static func buildWeightLog(fromCSV row: [String: String], rowNumber: Int) throws -> WeightLogEntry {
        guard let dateValue = field("date", in: row), let date = parseDay(dateValue) else {
            throw ImportError.invalidCSVRow(rowNumber, "для weight обязательно поле date в формате YYYY-MM-DD.")
        }
        guard let weight = parseDouble(field("weightkg", in: row)), weight > 0 else {
            throw ImportError.invalidCSVRow(rowNumber, "для weight обязательно поле weightKg больше 0.")
        }

        return WeightLogEntry(
            id: UUID(),
            date: date.startOfDay,
            weightKg: weight
        )
    }

    private static func buildWaterLog(fromCSV row: [String: String], rowNumber: Int) throws -> (key: String, value: Double) {
        guard let dateValue = field("date", in: row), let date = parseDay(dateValue) else {
            throw ImportError.invalidCSVRow(rowNumber, "для water обязательно поле date в формате YYYY-MM-DD.")
        }
        guard let liters = parseDouble(field("waterliters", in: row)), liters > 0 else {
            throw ImportError.invalidCSVRow(rowNumber, "для water обязательно поле waterLiters больше 0.")
        }

        return (Calendar.current.dayKey(for: date), liters)
    }

    private static func validateMacro(_ rawValue: String?, name: String, rowNumber: Int) throws -> Double? {
        guard let rawValue = trimmedNilIfEmpty(rawValue) else { return nil }
        guard let value = parseDouble(rawValue), value >= 0 else {
            throw ImportError.invalidCSVRow(rowNumber, "\(name) должен быть числом 0 или больше.")
        }
        return value
    }

    private static func validatePositiveOptional(_ rawValue: String?, name: String, rowNumber: Int) throws -> Double? {
        guard let rawValue = trimmedNilIfEmpty(rawValue) else { return nil }
        guard let value = parseDouble(rawValue), value > 0 else {
            throw ImportError.invalidCSVRow(rowNumber, "\(name) должен быть числом больше 0.")
        }
        return value
    }

    private static func parseEntryDate(_ dateString: String, time: String?, index: Int) throws -> Date {
        if let fullDate = parseDateTime(dateString) {
            return fullDate
        }

        guard let day = parseDay(dateString) else {
            throw ImportError.invalidEntry(index, "date должен быть в формате YYYY-MM-DD или ISO date-time.")
        }

        guard let time = trimmedNilIfEmpty(time) else {
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        }

        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            throw ImportError.invalidEntry(index, "time должен быть в формате HH:mm.")
        }

        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func parseMealType(_ rawValue: String?, fallbackDate: Date) -> MealType {
        if let normalized = rawValue?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            if ["breakfast", "завтрак"].contains(normalized) { return .breakfast }
            if ["secondbreakfast", "second_breakfast", "second breakfast", "второй завтрак"].contains(normalized) { return .secondBreakfast }
            if ["lunch", "обед"].contains(normalized) { return .lunch }
            if ["afternoonsnack", "afternoon_snack", "afternoon snack", "полдник"].contains(normalized) { return .afternoonSnack }
            if ["dinner", "ужин"].contains(normalized) { return .dinner }
            if ["latesnack", "late_snack", "late snack"].contains(normalized) { return .lateSnack }
            if ["snack", "перекус"].contains(normalized) { return inferredSnackMealType(for: fallbackDate) }
        }

        let hour = Calendar.current.component(.hour, from: fallbackDate)
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        case 16..<19:
            return .afternoonSnack
        case 19..<22:
            return .dinner
        default:
            return inferredSnackMealType(for: fallbackDate)
        }
    }

    private static func inferredSnackMealType(for date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 8..<11:
            return .secondBreakfast
        case 15..<18:
            return .afternoonSnack
        default:
            return .lateSnack
        }
    }

    private static func parseDay(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func parseDateTime(_ value: String) -> Date? {
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: value)
    }

    private static func normalizedText(from data: Data) -> String {
        var string = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        string = string
            .replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "```csv", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return string
    }

    private static func looksLikeCSV(_ string: String) -> Bool {
        guard let firstLine = string
            .split(whereSeparator: \.isNewline)
            .first?
            .lowercased() else {
            return false
        }

        return firstLine.contains("recordtype") || (firstLine.contains(",") && firstLine.contains("date"))
    }

    private static func detectDelimiter(in string: String) -> Character {
        guard let firstLine = string.split(whereSeparator: \.isNewline).first else {
            return ","
        }

        let commaCount = firstLine.filter { $0 == "," }.count
        let semicolonCount = firstLine.filter { $0 == ";" }.count
        return semicolonCount > commaCount ? ";" : ","
    }

    private static func parseCSVRows(from string: String, delimiter: Character) throws -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        let characters = Array(string)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case delimiter:
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                case "\r":
                    break
                default:
                    currentField.append(character)
                }
            }

            index += 1
        }

        if insideQuotes {
            throw ImportError.invalidCSV
        }

        currentRow.append(currentField)
        if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }

    private static func normalizedHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }

    private static func dictionary(from row: [String], headers: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for (index, header) in headers.enumerated() {
            result[header] = index < row.count ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        return result
    }

    private static func inferredRecordType(for row: [String: String]) -> String {
        if let recordType = field("recordtype", in: row)?.lowercased(), !recordType.isEmpty {
            return recordType
        }
        if field("weightkg", in: row) != nil {
            return "weight"
        }
        if field("waterliters", in: row) != nil {
            return "water"
        }
        return "entry"
    }

    private static func field(_ key: String, in row: [String: String]) -> String? {
        trimmedNilIfEmpty(row[key])
    }

    private static func parseDouble(_ string: String?) -> Double? {
        guard let string = trimmedNilIfEmpty(string) else { return nil }
        return Double(string.replacingOccurrences(of: ",", with: "."))
    }

    private static func exportNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: ",00", with: "")
            .replacingOccurrences(of: ".00", with: "")
    }

    private static func exportMealType(_ mealType: MealType) -> String {
        switch mealType {
        case .breakfast:
            return "breakfast"
        case .lunch:
            return "lunch"
        case .dinner:
            return "dinner"
        case .secondBreakfast, .afternoonSnack, .lateSnack:
            return "snack"
        }
    }

    private static func exportNotes(for entry: FoodEntry) -> String {
        let notes = [
            trimmedNilIfEmpty(entry.userText),
            trimmedNilIfEmpty(entry.portionDescription),
            trimmedNilIfEmpty(entry.analysis.assumptions)
        ].compactMap { $0 }

        return notes.joined(separator: " | ")
    }

    private static func trimmedNilIfEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func csvEscaped(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

@MainActor
private struct RawPayload: Decodable {
    var sourceApp: String?
    var entries: [RawEntry]?
    var weightLogs: [RawWeightLog]?
    var waterLogs: [RawWaterLog]?
}

@MainActor
private struct RawEntry: Decodable {
    var date: String
    var time: String?
    var mealType: String?
    var foodName: String
    var caloriesKcal: FlexibleDouble
    var proteinG: FlexibleDouble?
    var carbsG: FlexibleDouble?
    var fatG: FlexibleDouble?
    var weightGrams: FlexibleDouble?
    var notes: String?
}

@MainActor
private struct RawWeightLog: Decodable {
    var date: String
    var weightKg: FlexibleDouble
}

@MainActor
private struct RawWaterLog: Decodable {
    var date: String
    var liters: FlexibleDouble
}

@MainActor
private struct FlexibleDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
            return
        }

        if let string = try? container.decode(String.self) {
            let normalized = string
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let number = Double(normalized) {
                value = number
                return
            }
        }

        throw DecodingError.typeMismatch(
            Double.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected Double or numeric string."
            )
        )
    }
}
