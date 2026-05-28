import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case secondBreakfast
    case lunch
    case afternoonSnack
    case dinner
    case lateSnack

    var id: String { rawValue }

    /// Порядок отображения в «Рационе».
    static var rationOrder: [MealType] {
        [.breakfast, .secondBreakfast, .lunch, .afternoonSnack, .dinner, .lateSnack]
    }

    var title: String {
        switch self {
        case .breakfast: return "Завтрак"
        case .secondBreakfast: return "Второй завтрак"
        case .lunch: return "Обед"
        case .afternoonSnack: return "Полдник"
        case .dinner: return "Ужин"
        case .lateSnack: return "Перекус"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "cup.and.saucer.fill"
        case .secondBreakfast: return "takeoutbag.and.cup.and.straw.fill"
        case .lunch: return "fork.knife"
        case .afternoonSnack: return "leaf.fill"
        case .dinner: return "moon.stars.fill"
        case .lateSnack: return "carrot.fill"
        }
    }

    var defaultHour: Int {
        switch self {
        case .breakfast: return 8
        case .secondBreakfast: return 11
        case .lunch: return 13
        case .afternoonSnack: return 16
        case .dinner: return 19
        case .lateSnack: return 21
        }
    }

    static func inferred(fromAI value: String?) -> MealType? {
        guard let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased(),
              !normalized.isEmpty else {
            return nil
        }

        let compact = normalized
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        switch compact {
        case "breakfast", "zavtrak", "завтрак":
            return .breakfast
        case "secondbreakfast", "latebreakfast", "второйзавтрак":
            return .secondBreakfast
        case "lunch", "obed", "обед":
            return .lunch
        case "afternoonsnack", "snack", "poldnik", "полдник":
            return .afternoonSnack
        case "dinner", "uzhin", "ужин":
            return .dinner
        case "latesnack", "perecus", "perekus", "перекус":
            return .lateSnack
        default:
            return nil
        }
    }

    static func inferred(fromText text: String?) -> MealType? {
        let types = mentionedTypes(inText: text)
        guard types.count == 1 else { return nil }
        return types.first
    }

    static func mentionedTypes(inText text: String?) -> Set<MealType> {
        guard let normalized = text?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased(),
              !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var result: Set<MealType> = []

        if normalized.contains("второй завтрак") {
            result.insert(.secondBreakfast)
        } else if normalized.contains("завтрак") || normalized.contains("утром") {
            result.insert(.breakfast)
        }
        if normalized.contains("обед") || normalized.contains("ланч") {
            result.insert(.lunch)
        }
        if normalized.contains("полдник") {
            result.insert(.afternoonSnack)
        }
        if normalized.contains("ужин") || normalized.contains("вечером") {
            result.insert(.dinner)
        }
        if normalized.contains("перекус") || normalized.contains("снек") || normalized.contains("ночью") {
            result.insert(.lateSnack)
        }

        return result
    }

    static func inferredFromClock(_ date: Date) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10:
            return .breakfast
        case 10..<12:
            return .secondBreakfast
        case 12..<16:
            return .lunch
        case 16..<18:
            return .afternoonSnack
        case 18..<22:
            return .dinner
        default:
            return .lateSnack
        }
    }
}
