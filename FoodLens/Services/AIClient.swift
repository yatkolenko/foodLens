import Foundation
import UIKit

final class AIClient {
    static let shared = AIClient()

    private init() {}

    private struct RequestRoute: Hashable {
        let provider: AIProvider
        let model: String
        let apiKey: String
    }

    struct MealAnalysisResult {
        var analysis: FoodEntry.Analysis
        var estimatedWeightGrams: Double?
        var inferredMealType: MealType?
    }

    struct DayNutritionAnalysisInput {
        var day: Date
        var profile: UserProfile
        var entries: [FoodEntry]
        var totals: (kcal: Double, protein: Double, carbs: Double, fat: Double)
    }

    enum AIClientError: LocalizedError {
        case missingConfiguration(String)
        case missingFoodInput
        case invalidImageData
        case invalidResponse
        case apiError(String)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .missingConfiguration(let message):
                return message
            case .missingFoodInput:
                return "Добавьте фото, описание блюда или оба варианта вместе."
            case .invalidImageData:
                return "Не удалось подготовить изображение для отправки."
            case .invalidResponse:
                return "Сервис ИИ вернул неожиданный ответ."
            case .apiError(let message):
                return message
            case .decodingError:
                return "Не удалось разобрать структурированный ответ ИИ."
            }
        }
    }

    var configuration: AIConfiguration {
        AIConfiguration.current
    }

    func analyzeFood(
        image: UIImage?,
        userText: String?,
        weightGrams: Double?,
        portionDescription: String?,
        mealContextDate: Date? = nil
    ) async throws -> MealAnalysisResult {
        let normalizedUserText = userText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPortionDescription = portionDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTextInput = !(normalizedUserText?.isEmpty ?? true) || !(normalizedPortionDescription?.isEmpty ?? true)

        guard image != nil || hasTextInput else {
            throw AIClientError.missingFoodInput
        }

        let jpegData: Data?
        if let image {
            guard let data = image.jpegData(compressionQuality: 0.85) else {
                throw AIClientError.invalidImageData
            }
            jpegData = data
        } else {
            jpegData = nil
        }

        let weightPart: String
        if let weightGrams, weightGrams > 0 {
            weightPart = "Уточнение: вес порции = \(weightGrams) г."
        } else {
            weightPart = "Уточнение: вес порции не указан, оцени его по фото и/или описанию."
        }

        let portionPart: String
        if let portionDescription,
           !portionDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            portionPart = "Описание порции: \(portionDescription)."
        } else {
            portionPart = "Описание порции не указано."
        }

        let userTextPart: String
        if let normalizedUserText, !normalizedUserText.isEmpty {
            userTextPart = "Описание или состав от пользователя: \(normalizedUserText)."
        } else {
            userTextPart = "Описание или состав от пользователя отсутствуют."
        }

        let sourcePart: String
        switch (jpegData != nil, hasTextInput) {
        case (true, true):
            sourcePart = "Используй и фото, и текстовое описание вместе. Если есть расхождение, приоритет у явного текста пользователя."
        case (true, false):
            sourcePart = "Используй только фото блюда."
        case (false, true):
            sourcePart = "Фото нет, используй только текстовое описание и типичные размеры порций."
        default:
            sourcePart = ""
        }

        let mealContextPart: String
        if let mealContextDate {
            mealContextPart = """
            Локальная дата и примерное время приёма пищи: \(formattedMealContextDate(mealContextDate)).
            Если пользователь прямо сказал «на завтрак», «на обед», «на ужин» или указал другой тип приёма пищи, обязательно выбери именно его.
            Если явного указания нет, определи inferredMealType по времени и составу еды.
            """
        } else {
            mealContextPart = "Определи inferredMealType по явному тексту пользователя, а если явного указания нет — по наиболее вероятному сценарию употребления."
        }

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "inferredMealType": [
                    "type": "string",
                    "enum": MealType.rationOrder.map(\.rawValue)
                ],
                "foodName": ["type": "string"],
                "estimatedWeightGrams": ["type": "number"],
                "caloriesKcal": ["type": "number"],
                "proteinG": ["type": "number"],
                "carbsG": ["type": "number"],
                "fatG": ["type": "number"],
                "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                "assumptions": ["type": "string"],
                "items": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "name": ["type": "string"],
                            "quantityDescription": ["type": "string"],
                            "mealType": [
                                "type": "string",
                                "enum": MealType.rationOrder.map(\.rawValue)
                            ],
                            "estimatedWeightGrams": ["type": "number"],
                            "caloriesKcal": ["type": "number"],
                            "proteinG": ["type": "number"],
                            "carbsG": ["type": "number"],
                            "fatG": ["type": "number"]
                        ],
                        "required": [
                            "name",
                            "quantityDescription",
                            "mealType",
                            "estimatedWeightGrams",
                            "caloriesKcal",
                            "proteinG",
                            "carbsG",
                            "fatG"
                        ]
                    ]
                ]
            ],
            "required": [
                "inferredMealType",
                "foodName",
                "estimatedWeightGrams",
                "caloriesKcal",
                "proteinG",
                "carbsG",
                "fatG",
                "confidence",
                "assumptions",
                "items"
            ]
        ]

        let prompt = """
        Ты — нутриционист. Проанализируй приём пищи и оцени порцию:
        тип приёма пищи, название блюда, общий вес порции (г), калории (ккал), белок, углеводы и жиры (г).
        \(sourcePart)
        \(mealContextPart)
        Если пользователь явно перечислил продукты, напитки или добавки в тексте, ты обязан учесть каждый из них в расчёте, даже если их нет на фото.
        Это особенно важно для напитков, алкоголя, кофе, чая, хлеба, соусов, масла, десертов и любых дополнительных позиций вне кадра.
        Если в тексте указаны объёмы или количества вроде 0.33 пива, 2 чашки кофе, 1 кусок хлеба, используй именно их и включай в итоговую сумму.
        Если текст похож на дневник за день с заголовками «Завтрак», «Перекус», «Обед», «Дополнительно», «Ужин» и списками под ними, обработай весь текст целиком.
        Не останавливайся на первом заголовке и не возвращай только первый приём пищи.
        Каждый пункт списка под каждым заголовком должен попасть в items, а mealType должен соответствовать заголовку или логичному месту этого блока в дне.
        Если пункт содержит составное блюдо с несколькими явными продуктами, можешь разбить его на несколько items, но нельзя терять сам пункт.
        Сначала разбей приём пищи на все отдельные компоненты и верни их в items, затем сложи их в один общий результат.
        Для каждого элемента items заполни mealType. Если пользователь сказал «на обед», все продукты этого блока должны получить lunch. Если в одном тексте есть несколько блоков вроде «на завтрак ... на ужин ...», распределяй продукты по соответствующим mealType.
        Если пользователь прислал длинный список всей еды за день без явных слов «завтрак», «обед», «ужин», НЕ складывай всё в один mealType.
        В таком случае распределяй позиции по типичному дню: утренние продукты вроде кофе, яиц, каши, сырников — breakfast; йогурт, Skyr, quark, протеин, фрукты — secondBreakfast или afternoonSnack; основные блюда с рыбой, мясом, курицей, лавашом, овощами — lunch или dinner по порядку списка; творог поздно в списке — lateSnack.
        Если не уверен, всё равно сделай разумное распределение по items, а не один общий ужин.
        Никогда не игнорируй текстовое описание только потому, что фото показывает только часть приёма пищи.
        Если вес не указан пользователем, оцени его по фото и/или описанию.
        Если в тексте перечислено несколько продуктов, в items должна быть отдельная строка на каждый понятный продукт или напиток.
        Текст мог прийти из диктовки. Исправляй очевидные ошибки распознавания названий еды и брендов по контексту: Skyr, скайр, скир, skier, sky, scare — это обычно кисломолочный продукт Skyr.
        Названия брендов можно оставлять латиницей, например Skyr.
        Поле quantityDescription пиши по-русски и кратко: например «200 г», «3 шт», «2 ст. л.», «330 мл».
        В name указывай только конкретный продукт или блюдо без лишней воды.
        Сумма caloriesKcal, proteinG, carbsG и fatG по items должна быть максимально близка к общему итогу.
        Все текстовые поля ответа обязательно верни на русском языке.
        Поле inferredMealType верни одним из rawValue: \(MealType.rationOrder.map(\.rawValue).joined(separator: ", ")).
        Поле foodName должно быть кратким и естественным русским названием блюда или приёма пищи.
        Если приём пищи состоит из нескольких продуктов, foodName должен отражать весь состав, а не только самое заметное блюдо на фото.
        Поле assumptions тоже пиши только по-русски.
        В assumptions коротко перечисли, какие дополнительные позиции из текста были включены в расчёт, если они не видны на фото, и на чём основаны оценки порций.
        \(weightPart)
        \(portionPart)
        \(userTextPart)
        Верни только JSON без markdown и без пояснений. Строго следуй этой JSON-схеме:
        \(schemaDescription(from: schema))
        """

        let json = try await requestStructuredJSON(
            prompt: prompt,
            schema: schema,
            imageJPEGData: jpegData
        )

        guard let data = json.trimmedForDecoding.data(using: .utf8) else {
            throw AIClientError.decodingError
        }

        struct FoodAI: Codable {
            struct Item: Codable {
                var name: String
                var quantityDescription: String
                var mealType: String
                var estimatedWeightGrams: Double
                var caloriesKcal: Double
                var proteinG: Double
                var carbsG: Double
                var fatG: Double
            }

            var inferredMealType: String
            var foodName: String
            var estimatedWeightGrams: Double
            var caloriesKcal: Double
            var proteinG: Double
            var carbsG: Double
            var fatG: Double
            var confidence: Double
            var assumptions: String
            var items: [Item]
        }

        do {
            let decoded = try JSONDecoder().decode(FoodAI.self, from: data)
            return MealAnalysisResult(
                analysis: FoodEntry.Analysis(
                    foodName: decoded.foodName,
                    caloriesKcal: decoded.caloriesKcal,
                    proteinG: decoded.proteinG,
                    carbsG: decoded.carbsG,
                    fatG: decoded.fatG,
                    confidence: decoded.confidence,
                    assumptions: decoded.assumptions.isEmpty ? nil : decoded.assumptions,
                    items: decoded.items.map { item in
                        FoodEntry.Analysis.ItemBreakdown(
                            name: item.name,
                            quantityDescription: item.quantityDescription,
                            mealType: MealType.inferred(fromAI: item.mealType),
                            estimatedWeightGrams: item.estimatedWeightGrams > 0 ? item.estimatedWeightGrams : nil,
                            caloriesKcal: item.caloriesKcal,
                            proteinG: item.proteinG,
                            carbsG: item.carbsG,
                            fatG: item.fatG
                        )
                    }
                ),
                estimatedWeightGrams: decoded.estimatedWeightGrams > 0 ? decoded.estimatedWeightGrams : nil,
                inferredMealType: MealType.inferred(fromAI: decoded.inferredMealType)
            )
        } catch {
            throw AIClientError.decodingError
        }
    }

    func analyzeNutritionDay(_ input: DayNutritionAnalysisInput) async throws -> DailyNutritionAdvice {
        let dayKey = Calendar.current.dayKey(for: input.day)
        let dayTitle = formattedMealContextDate(input.day)
        let entriesText: String

        if input.entries.isEmpty {
            entriesText = "За день нет записей еды."
        } else {
            entriesText = input.entries.map { entry in
                "\(entry.mealType.title): \(entry.analysis.foodName) — \(rounded(entry.analysis.caloriesKcal)) ккал, Б \(rounded(entry.analysis.proteinG)) г, У \(rounded(entry.analysis.carbsG)) г, Ж \(rounded(entry.analysis.fatG)) г"
            }
            .joined(separator: "\n")
        }

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "summary": ["type": "string"],
                "positives": [
                    "type": "array",
                    "items": ["type": "string"]
                ],
                "improvements": [
                    "type": "array",
                    "items": ["type": "string"]
                ],
                "nextStep": ["type": "string"]
            ],
            "required": ["summary", "positives", "improvements", "nextStep"]
        ]

        let prompt = """
        Ты — спокойный нутриционист в приложении дневника питания.
        Проанализируй один день питания пользователя и дай короткий практичный совет на русском языке.
        Не ставь диагнозы и не используй медицинские обещания.
        Пиши конкретно: что было хорошо, что стоит улучшить, и один понятный следующий шаг.
        Ответ должен быть мягким, без осуждения.

        Дата: \(dayTitle)
        Цели дня:
        Калории: \(rounded(input.profile.targetCaloriesKcalPerDay)) ккал
        Белок: \(rounded(input.profile.targetProteinGPerDay)) г
        Углеводы: \(rounded(input.profile.targetCarbsGPerDay)) г
        Жиры: \(rounded(input.profile.targetFatGPerDay)) г

        Итог дня:
        Калории: \(rounded(input.totals.kcal)) ккал
        Белок: \(rounded(input.totals.protein)) г
        Углеводы: \(rounded(input.totals.carbs)) г
        Жиры: \(rounded(input.totals.fat)) г

        Записи:
        \(entriesText)

        Верни только JSON без markdown. Строго следуй схеме:
        \(schemaDescription(from: schema))
        """

        let json = try await requestStructuredJSON(prompt: prompt, schema: schema)
        guard let data = json.trimmedForDecoding.data(using: .utf8) else {
            throw AIClientError.decodingError
        }

        struct DayAI: Codable {
            var summary: String
            var positives: [String]
            var improvements: [String]
            var nextStep: String
        }

        do {
            let decoded = try JSONDecoder().decode(DayAI.self, from: data)
            return DailyNutritionAdvice(
                dayKey: dayKey,
                generatedAt: Date(),
                summary: decoded.summary,
                positives: Array(decoded.positives.prefix(3)),
                improvements: Array(decoded.improvements.prefix(3)),
                nextStep: decoded.nextStep
            )
        } catch {
            throw AIClientError.decodingError
        }
    }

    private func requestStructuredJSON(
        prompt: String,
        schema: [String: Any],
        imageJPEGData: Data? = nil
    ) async throws -> String {
        let configuration = AIConfiguration.current
        let routes = requestRoutes(from: configuration)
        guard !routes.isEmpty else {
            throw AIClientError.missingConfiguration(configuration.setupInstructions)
        }

        var lastError: AIClientError?

        for (index, route) in routes.enumerated() {
            do {
                return try await sendRequest(
                    prompt: prompt,
                    schema: schema,
                    imageJPEGData: imageJPEGData,
                    route: route
                )
            } catch let error as AIClientError {
                lastError = error
                let hasMoreRoutes = index < routes.count - 1
                guard hasMoreRoutes, shouldFallback(for: error) else {
                    break
                }
            }
        }

        if let lastError {
            throw normalizedFinalError(lastError, attemptedRoutesCount: routes.count)
        }

        throw AIClientError.invalidResponse
    }

    private func requestRoutes(from configuration: AIConfiguration) -> [RequestRoute] {
        var routes: [RequestRoute] = []
        let fallbackProviderOrder: [AIProvider] = [.gemini, .cohere, .mistral, .openai]

        func appendUnique(provider: AIProvider, model: String?, apiKey: String?) {
            guard let model = model?.trimmedForDecoding, !model.isEmpty,
                  let apiKey = apiKey?.trimmedForDecoding, !apiKey.isEmpty else {
                return
            }

            let route = RequestRoute(provider: provider, model: model, apiKey: apiKey)
            guard !routes.contains(route) else { return }
            routes.append(route)
        }

        func appendProvider(_ provider: AIProvider) {
            switch provider {
            case .gemini:
                appendUnique(provider: .gemini, model: configuration.geminiModel, apiKey: configuration.geminiAPIKey)
                appendUnique(provider: .gemini, model: configuration.geminiFallbackModel, apiKey: configuration.geminiAPIKey)
            case .openai:
                appendUnique(provider: .openai, model: configuration.openAIModel, apiKey: configuration.openAIAPIKey)
                appendUnique(provider: .openai, model: configuration.openAIFallbackModel, apiKey: configuration.openAIAPIKey)
            case .cohere:
                appendUnique(provider: .cohere, model: configuration.cohereModel, apiKey: configuration.cohereAPIKey)
                appendUnique(provider: .cohere, model: configuration.cohereFallbackModel, apiKey: configuration.cohereAPIKey)
            case .mistral:
                appendUnique(provider: .mistral, model: configuration.mistralModel, apiKey: configuration.mistralAPIKey)
                appendUnique(provider: .mistral, model: configuration.mistralFallbackModel, apiKey: configuration.mistralAPIKey)
            }
        }

        appendProvider(configuration.provider)

        for provider in fallbackProviderOrder where provider != configuration.provider {
            appendProvider(provider)
        }

        return routes
    }

    private func shouldFallback(for error: AIClientError) -> Bool {
        switch error {
        case .apiError:
            return true
        case .invalidResponse, .decodingError:
            return true
        case .missingConfiguration, .missingFoodInput, .invalidImageData:
            return false
        }
    }

    private func normalizedFinalError(_ error: AIClientError, attemptedRoutesCount: Int) -> AIClientError {
        switch error {
        case .apiError(let message):
            return .apiError(userFacingAPIMessage(from: message, attemptedRoutesCount: attemptedRoutesCount))
        default:
            return error
        }
    }

    private func userFacingAPIMessage(from message: String, attemptedRoutesCount: Int) -> String {
        let normalized = message.lowercased()

        if normalized.contains("high demand")
            || normalized.contains("rate limit")
            || normalized.contains("resource exhausted")
            || normalized.contains("too many requests")
            || normalized.contains("temporarily unavailable")
            || normalized.contains("service unavailable")
            || normalized.contains("overloaded")
            || normalized.contains("try again later")
            || normalized.contains("credits")
            || normalized.contains("credit balance")
            || normalized.contains("insufficient balance")
            || normalized.contains("insufficient credits")
            || normalized.contains("429")
            || normalized.contains("503") {
            if attemptedRoutesCount > 1 {
                return "Основной сервис распознавания сейчас недоступен или упёрся в лимиты. Приложение попробовало все настроенные резервные варианты, но они тоже не ответили. Попробуйте ещё раз чуть позже или заполните запись вручную."
            }

            return "Сервис распознавания сейчас недоступен или упёрся в лимиты. Попробуйте ещё раз чуть позже или заполните запись вручную."
        }

        if normalized.contains("api key not valid")
            || normalized.contains("invalid api key")
            || normalized.contains("permission denied")
            || normalized.contains("unauthenticated")
            || normalized.contains("forbidden")
            || normalized.contains("401")
            || normalized.contains("403") {
            return "Не удалось авторизоваться в сервисе распознавания. Проверьте ключ и настройки в AppConfig.env."
        }

        return message
    }

    private func sendRequest(
        prompt: String,
        schema: [String: Any],
        imageJPEGData: Data?,
        route: RequestRoute
    ) async throws -> String {
        switch route.provider {
        case .openai:
            return try await sendOpenAIRequest(
                prompt: prompt,
                schema: schema,
                imageJPEGData: imageJPEGData,
                model: route.model,
                apiKey: route.apiKey
            )
        case .gemini:
            return try await sendGeminiRequest(
                prompt: prompt,
                schema: schema,
                imageJPEGData: imageJPEGData,
                model: route.model,
                apiKey: route.apiKey
            )
        case .cohere:
            return try await sendCohereRequest(
                prompt: prompt,
                schema: schema,
                imageJPEGData: imageJPEGData,
                model: route.model,
                apiKey: route.apiKey
            )
        case .mistral:
            return try await sendMistralRequest(
                prompt: prompt,
                schema: schema,
                imageJPEGData: imageJPEGData,
                model: route.model,
                apiKey: route.apiKey
            )
        }
    }

    private func sendOpenAIRequest(
        prompt: String,
        schema: [String: Any],
        imageJPEGData: Data?,
        model: String,
        apiKey: String
    ) async throws -> String {
        var content: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]

        if let imageJPEGData {
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(imageJPEGData.base64EncodedString())",
                    "detail": "auto"
                ]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "structured_output",
                    "schema": schema,
                    "strict": true
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data = try await perform(request)

        let root = try decodeOpenAIResponse(data: data)
        if let outputText = root.choices.first?.message.content, !outputText.isEmpty {
            return outputText
        }
        throw AIClientError.invalidResponse
    }

    private func sendGeminiRequest(
        prompt: String,
        schema: [String: Any],
        imageJPEGData: Data?,
        model: String,
        apiKey: String
    ) async throws -> String {
        var parts: [[String: Any]] = []
        if let imageJPEGData {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imageJPEGData.base64EncodedString()
                ]
            ])
        }
        parts.append(["text": prompt])

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": parts
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]

        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? model
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data = try await perform(request)
        let root = try decodeGeminiResponse(data: data)

        if let blockReason = root.promptFeedback?.blockReason, !blockReason.isEmpty {
            throw AIClientError.apiError("Gemini заблокировал запрос: \(blockReason)")
        }

        let text = root.candidates?
            .compactMap { $0.content?.parts }
            .flatMap { $0 }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmedForDecoding

        guard let text, !text.isEmpty else {
            throw AIClientError.invalidResponse
        }

        return text
    }

    private func sendCohereRequest(
        prompt: String,
        schema: [String: Any],
        imageJPEGData: Data?,
        model: String,
        apiKey: String
    ) async throws -> String {
        var content: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]

        if let imageJPEGData {
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(imageJPEGData.base64EncodedString())"
                ]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "response_format": [
                "type": "json_object",
                "json_schema": schema
            ],
            "temperature": 0.2
        ]

        var request = URLRequest(url: URL(string: "https://api.cohere.com/v2/chat")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data = try await perform(request)
        let root = try decodeCohereResponse(data: data)
        let text = root.message?.content?
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmedForDecoding

        guard let text, !text.isEmpty else {
            throw AIClientError.invalidResponse
        }

        return text
    }

    private func sendMistralRequest(
        prompt: String,
        schema: [String: Any],
        imageJPEGData: Data?,
        model: String,
        apiKey: String
    ) async throws -> String {
        let content: Any
        if let imageJPEGData {
            content = [
                [
                    "type": "text",
                    "text": prompt
                ],
                [
                    "type": "image_url",
                    "image_url": "data:image/jpeg;base64,\(imageJPEGData.base64EncodedString())"
                ]
            ]
        } else {
            content = prompt
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "response_format": [
                "type": "json_object"
            ],
            "temperature": 0.2
        ]

        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data = try await perform(request)
        let root = try decodeMistralResponse(data: data)
        if let outputText = root.choices.first?.message.contentString, !outputText.isEmpty {
            return outputText.trimmedForDecoding
        }
        throw AIClientError.invalidResponse
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AIClientError.apiError(apiErrorMessage(from: data))
        }
        return data
    }

    private func apiErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let status = error["status"] as? String, !status.isEmpty {
                return status
            }
        }

        return String(data: data, encoding: .utf8) ?? "Неизвестная ошибка AI API."
    }

    private struct OpenAIChatCompletionResponse: Decodable {
        let choices: [Choice]
    }

    private struct Choice: Decodable {
        let message: Message
    }

    private struct Message: Decodable {
        let content: String
    }

    private func decodeOpenAIResponse(data: Data) throws -> OpenAIChatCompletionResponse {
        do {
            return try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        } catch {
            throw AIClientError.decodingError
        }
    }

    private struct GeminiGenerateContentResponse: Decodable {
        let candidates: [GeminiCandidate]?
        let promptFeedback: GeminiPromptFeedback?
    }

    private struct GeminiCandidate: Decodable {
        let content: GeminiContent?
    }

    private struct GeminiContent: Decodable {
        let parts: [GeminiPart]?
    }

    private struct GeminiPart: Decodable {
        let text: String?
    }

    private struct GeminiPromptFeedback: Decodable {
        let blockReason: String?
    }

    private func decodeGeminiResponse(data: Data) throws -> GeminiGenerateContentResponse {
        do {
            return try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        } catch {
            throw AIClientError.decodingError
        }
    }

    private struct CohereChatResponse: Decodable {
        let message: CohereMessage?
    }

    private struct CohereMessage: Decodable {
        let content: [CohereContentPart]?
    }

    private struct CohereContentPart: Decodable {
        let text: String?
    }

    private func decodeCohereResponse(data: Data) throws -> CohereChatResponse {
        do {
            return try JSONDecoder().decode(CohereChatResponse.self, from: data)
        } catch {
            throw AIClientError.decodingError
        }
    }

    private struct MistralChatCompletionResponse: Decodable {
        let choices: [MistralChoice]
    }

    private struct MistralChoice: Decodable {
        let message: MistralMessage
    }

    private struct MistralMessage: Decodable {
        let contentString: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let stringValue = try? container.decode(String.self, forKey: .content) {
                contentString = stringValue
                return
            }

            if let parts = try? container.decode([MistralContentPart].self, forKey: .content) {
                contentString = parts.compactMap(\.text).joined(separator: "\n")
                return
            }

            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Mistral message content to be a string or text parts."
                )
            )
        }

        private enum CodingKeys: String, CodingKey {
            case content
        }
    }

    private struct MistralContentPart: Decodable {
        let text: String?
    }

    private func decodeMistralResponse(data: Data) throws -> MistralChatCompletionResponse {
        do {
            return try JSONDecoder().decode(MistralChatCompletionResponse.self, from: data)
        } catch {
            throw AIClientError.decodingError
        }
    }

    private func schemaDescription(from schema: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: schema, options: []),
              let string = String(data: data, encoding: String.Encoding.utf8) else {
            return "{}"
        }
        return string
    }

    private func formattedMealContextDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    private func rounded(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

private extension String {
    var trimmedForDecoding: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
