import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DataTransferView: View {
    @EnvironmentObject private var store: FoodStore

    @State private var showingFileImporter = false
    @State private var showingFileExporter = false
    @State private var importSuccessMessage: String?
    @State private var importErrorMessage: String?
    @State private var exportSuccessMessage: String?
    @State private var exportErrorMessage: String?
    @State private var copyFeedbackMessage: String?
    @State private var exportDocument = TransferCSVDocument(text: "")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introCard
                stepsCard
                requiredFieldsCard
                promptCard
                exampleCard
                importCard
                exportCard

                if let importSuccessMessage {
                    statusCard(
                        title: "Импорт завершён",
                        message: importSuccessMessage,
                        color: DesignTokens.accentGreen
                    )
                }

                if let importErrorMessage {
                    statusCard(
                        title: "Ошибка импорта",
                        message: importErrorMessage,
                        color: .red
                    )
                }

                if let exportSuccessMessage {
                    statusCard(
                        title: "Экспорт завершён",
                        message: exportSuccessMessage,
                        color: DesignTokens.accentGreen
                    )
                }

                if let exportErrorMessage {
                    statusCard(
                        title: "Ошибка экспорта",
                        message: exportErrorMessage,
                        color: .red
                    )
                }

                if let copyFeedbackMessage {
                    Text(copyFeedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.background)
        .navigationTitle("Перенос данных")
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: exportFileName
        ) { result in
            handleExport(result)
        }
    }

    private var introCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Как это работает")
                    .font(.headline)
                Text("Если старое приложение не умеет делать экспорт, можно использовать скриншоты и AI chat как промежуточный конвертер в CSV.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("Главное для импорта - история приёмов пищи. Вода и история веса тоже поддерживаются, но они полностью необязательны.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("После импорта записи еды попадут в FoodLens, а план и дневные цели останутся по текущему профилю приложения.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private var stepsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Пошагово")
                    .font(.headline)
                stepRow(number: 1, text: "Откройте старое приложение и сделайте скриншоты истории питания, воды и веса.")
                stepRow(number: 2, text: "Загрузите скриншоты в AI chat и отправьте prompt ниже.")
                stepRow(number: 3, text: "Попросите AI chat вернуть готовый CSV-файл для скачивания.")
                stepRow(number: 4, text: "Выберите файл здесь, а приложение проверит формат и импортирует данные.")
            }
        }
    }

    private var requiredFieldsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Какие данные нужны")
                    .font(.headline)
                Text("Главное для записи еды: название блюда, дата, калории и тип приёма пищи. Белок очень желателен, вес порции тоже полезен, но они могут отсутствовать.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("Если `mealType` нет, FoodLens попробует определить его по времени. Если `proteinG`, `carbsG` или `fatG` нет, они будут импортированы как `0`. Если `weightGrams` нет, запись просто сохранится без веса.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("Текущий вес и вода не обязательны: если их нет в старом приложении, просто не добавляйте `weightLogs` и `waterLogs`.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private var promptCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Prompt для AI chat")
                        .font(.headline)
                    Spacer()
                    Button("Скопировать") {
                        copyToPasteboard(LegacyImportService.aiChatPrompt, message: "Prompt скопирован.")
                    }
                    .font(.footnote.weight(.semibold))
                }

                Text(LegacyImportService.aiChatPrompt)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var exampleCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Пример CSV")
                        .font(.headline)
                    Spacer()
                    Button("Скопировать") {
                        copyToPasteboard(LegacyImportService.exampleCSV, message: "Пример CSV скопирован.")
                    }
                    .font(.footnote.weight(.semibold))
                }

                Text(LegacyImportService.exampleCSV)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var importCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Импорт файла")
                    .font(.headline)
                Text("Лучше всего подходит `.csv`. Старый `.json` формат тоже поддерживается. Если в файле будут дубликаты уже импортированных записей, они будут пропущены.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)

                Button {
                    importSuccessMessage = nil
                    importErrorMessage = nil
                    showingFileImporter = true
                } label: {
                    Text("Выбрать файл для импорта")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var exportCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Экспорт моих данных")
                    .font(.headline)
                Text("Можно выгрузить текущий дневник, историю веса и воду в CSV. Такой файл потом удобно хранить как резервную копию или использовать для переноса.")
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)

                Button {
                    exportSuccessMessage = nil
                    exportErrorMessage = nil
                    exportDocument = TransferCSVDocument(
                        text: LegacyImportService.exportCSV(
                            entries: store.entries,
                            weightLogs: store.sortedWeightLogs(),
                            waterByDay: store.waterLitersByDay
                        )
                    )
                    showingFileExporter = true
                } label: {
                    Text("Экспортировать в CSV")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.footnote.weight(.bold))
                .foregroundStyle(DesignTokens.accentGreen)
            Text(text)
                .font(.footnote)
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func statusCard(title: String, message: String, color: Color) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private func copyToPasteboard(_ text: String, message: String) {
        UIPasteboard.general.string = text
        copyFeedbackMessage = message
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFile(from: url)
        case .failure:
            importErrorMessage = "Не удалось открыть файл для импорта."
        }
    }

    private func importFile(from url: URL) {
        importSuccessMessage = nil
        importErrorMessage = nil

        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try LegacyImportService.parse(data: data, fileExtension: url.pathExtension)
            let report = store.importLegacyPayload(payload)
            importSuccessMessage = importSummary(sourceApp: payload.sourceApp, report: report)
        } catch let error as LegacyImportService.ImportError {
            importErrorMessage = error.localizedDescription
        } catch {
            importErrorMessage = "Не удалось прочитать файл или разобрать его содержимое."
        }
    }

    private func handleExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            exportSuccessMessage = "CSV успешно подготовлен и сохранён."
        case .failure:
            exportErrorMessage = "Не удалось сохранить CSV-файл."
        }
    }

    private func importSummary(sourceApp: String?, report: FoodStore.ImportReport) -> String {
        let sourcePart: String
        if let sourceApp, !sourceApp.isEmpty {
            sourcePart = "Источник: \(sourceApp). "
        } else {
            sourcePart = ""
        }

        return sourcePart +
        "Добавлено записей еды: \(report.addedEntries), пропущено дубликатов: \(report.skippedEntries). " +
        "Добавлено записей веса: \(report.addedWeightLogs), пропущено дубликатов: \(report.skippedWeightLogs). " +
        "Обновлено дней с водой: \(report.updatedWaterDays)."
    }

    private var exportFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "FoodLens-\(formatter.string(from: Date()))"
    }
}
