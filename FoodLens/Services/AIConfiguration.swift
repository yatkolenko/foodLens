import Foundation

enum AIProvider: String, CaseIterable {
    case gemini
    case openai
    case cohere
    case mistral

    var title: String {
        switch self {
        case .gemini:
            return "Google Gemini"
        case .openai:
            return "OpenAI"
        case .cohere:
            return "Cohere"
        case .mistral:
            return "Mistral"
        }
    }

    var keyEnvName: String {
        switch self {
        case .gemini:
            return "GEMINI_API_KEY"
        case .openai:
            return "OPENAI_API_KEY"
        case .cohere:
            return "COHERE_API_KEY"
        case .mistral:
            return "MISTRAL_API_KEY"
        }
    }
}

struct AIConfiguration {
    static let envResourceName = "AppConfig"
    static let envResourceExtension = "env"

    var provider: AIProvider
    var openAIAPIKey: String?
    var openAIModel: String
    var openAIFallbackModel: String?
    var geminiAPIKey: String?
    var geminiModel: String
    var geminiFallbackModel: String?
    var cohereAPIKey: String?
    var cohereModel: String
    var cohereFallbackModel: String?
    var mistralAPIKey: String?
    var mistralModel: String
    var mistralFallbackModel: String?

    static var current: AIConfiguration {
        load()
    }

    var activeProviderTitle: String {
        provider.title
    }

    var activeModel: String {
        switch provider {
        case .gemini:
            return geminiModel
        case .openai:
            return openAIModel
        case .cohere:
            return cohereModel
        case .mistral:
            return mistralModel
        }
    }

    var activeAPIKey: String? {
        switch provider {
        case .gemini:
            return geminiAPIKey
        case .openai:
            return openAIAPIKey
        case .cohere:
            return cohereAPIKey
        case .mistral:
            return mistralAPIKey
        }
    }

    var isConfigured: Bool {
        !(activeAPIKey?.trimmed.isEmpty ?? true)
    }

    var setupInstructions: String {
        "Настройте \(Self.envResourceName).\(Self.envResourceExtension): выберите AI_PROVIDER=gemini, openai, cohere или mistral и заполните \(provider.keyEnvName) для активного провайдера."
    }

    private static func load() -> AIConfiguration {
        let fileValues = EnvFileLoader.bundleValues(
            resourceName: envResourceName,
            resourceExtension: envResourceExtension
        )
        let processValues = ProcessInfo.processInfo.environment
        let values = fileValues.merging(processValues) { _, processValue in processValue }

        let providerValue = values["AI_PROVIDER"]?.trimmed.lowercased() ?? AIProvider.gemini.rawValue
        let provider = AIProvider(rawValue: providerValue) ?? .gemini

        return AIConfiguration(
            provider: provider,
            openAIAPIKey: normalize(values["OPENAI_API_KEY"]),
            openAIModel: normalize(values["OPENAI_MODEL"]) ?? "gpt-4o-mini",
            openAIFallbackModel: normalize(values["OPENAI_FALLBACK_MODEL"]),
            geminiAPIKey: normalize(values["GEMINI_API_KEY"]),
            geminiModel: normalize(values["GEMINI_MODEL"]) ?? "gemini-2.5-flash",
            geminiFallbackModel: normalize(values["GEMINI_FALLBACK_MODEL"]) ?? "gemini-2.5-flash-lite",
            cohereAPIKey: normalize(values["COHERE_API_KEY"]),
            cohereModel: normalize(values["COHERE_MODEL"]) ?? "command-a-vision-07-2025",
            cohereFallbackModel: normalize(values["COHERE_FALLBACK_MODEL"]),
            mistralAPIKey: normalize(values["MISTRAL_API_KEY"]),
            mistralModel: normalize(values["MISTRAL_MODEL"]) ?? "mistral-small-latest",
            mistralFallbackModel: normalize(values["MISTRAL_FALLBACK_MODEL"]) ?? "ministral-8b-2512"
        )
    }

    private static func normalize(_ value: String?) -> String? {
        let trimmed = value?.trimmed ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum EnvFileLoader {
    static func bundleValues(resourceName: String, resourceExtension: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }

        return parse(contents)
    }

    static func parse(_ text: String) -> [String: String] {
        var values: [String: String] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix("//") else { continue }
            guard let separator = line.firstIndex(of: "=") else { continue }

            let key = String(line[..<separator]).trimmed
            guard !key.isEmpty else { continue }

            var value = String(line[line.index(after: separator)...]).trimmed
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
                value.removeFirst()
                value.removeLast()
            }

            values[key] = value
        }

        return values
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
