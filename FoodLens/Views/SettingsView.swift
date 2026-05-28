import SwiftUI

struct SettingsView: View {
    private var configuration: AIConfiguration {
        AIConfiguration.current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Настройки")
                        .font(.largeTitle.bold())
                    Text("Секреты хранятся локально на устройстве.")
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Искусственный интеллект")
                            .font(.headline)
                        statusRow("Статус", configuration.isConfigured ? "Настроен" : "Не настроен")
                        statusRow("Файл", "AppConfig.env")
                        Text(
                            configuration.isConfigured
                            ? "Ключ найден. Если захотите сменить сервис распознавания, обновите значения в AppConfig.env и пересоберите приложение."
                            : configuration.setupInstructions
                        )
                            .font(.footnote)
                            .foregroundStyle(configuration.isConfigured ? DesignTokens.textSecondary : .red)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Где используется фото-анализ")
                            .font(.headline)
                        Text("Фото-анализ сейчас используется для разбора блюда по снимку: название, примерная порция, калории и БЖУ. План питания, пересчёт калорий и прогноз по сроку достижения веса считаются локально по формуле Миффлина-Сан Жеора.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Приватность")
                            .font(.headline)
                        Text("Данные дневника, вес и вода хранятся на устройстве. При запуске распознавания отправляется только фото блюда и ваши текстовые уточнения к нему.")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
        .background(DesignTokens.background)
        .navigationTitle("Настройки")
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
