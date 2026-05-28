import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: FoodStore

    private var profile: UserProfile? {
        store.profile
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var currentPlan: NutritionPlan? {
        guard let profile else { return nil }
        return GoalsCalculator.plan(
            sex: profile.sex,
            age: profile.age,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activity: profile.activity,
            goal: profile.goal,
            targetWeightKg: profile.goalTargetWeightKg,
            customCaloriesKcalPerDay: profile.customCaloriesKcalPerDay
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let profile {
                        profileSummaryCard(profile)

                        if let plan = currentPlan, let targetWeight = profile.goalTargetWeightKg, let projection = plan.projection {
                            CardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Прогноз по цели")
                                        .font(.headline)
                                    Text("При \(Int(plan.caloriesKcal)) ккал/день цель \(formattedWeight(targetWeight)) ориентировочно достигается к \(longDate(projection.estimatedDate)).")
                                        .font(.footnote)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            }
                        }

                        NavigationLink {
                            EditProfileView(profile: profile)
                        } label: {
                            Text("Изменить параметры и цель")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        CardView {
                            Text("Профиль ещё не создан.")
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        HStack {
                            Text("Фото-анализ и приватность")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(DesignTokens.cardElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                                )
                                .shadow(color: DesignTokens.cardShadow, radius: 12, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DataTransferView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Перенос данных")
                                Text("Импорт истории из другого приложения через CSV")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(DesignTokens.cardElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                                )
                                .shadow(color: DesignTokens.cardShadow, radius: 12, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    CardView {
                        VStack(alignment: .center, spacing: 8) {
                            Text("О приложении")
                                .font(.headline)
                            Text("Dmytro Yatkolenko for personal use with my love Sofiia \(Text(Image(systemName: "heart.fill")).foregroundStyle(.red))")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            Text("Версия \(appVersion)")
                                .font(.footnote)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(DesignTokens.background)
            .navigationTitle("Профиль")
        }
    }

    private func profileSummaryCard(_ profile: UserProfile) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Параметры")
                    .font(.headline)

                row("Цель", profile.goal.title)
                if let targetWeight = profile.goalTargetWeightKg, profile.goal == .lose {
                    row("Цель по весу", formattedWeight(targetWeight))
                }
                row("Вес", formattedWeight(profile.weightKg))
                row("Активность", profile.activity.title)
                row("Ккал/день", "\(Int(profile.targetCaloriesKcalPerDay))")
                row("Белок", "\(Int(profile.targetProteinGPerDay)) г")
                row("Углеводы", "\(Int(profile.targetCarbsGPerDay)) г")
                row("Жиры", "\(Int(profile.targetFatGPerDay)) г")

                if let summary = profile.aiPlanSummary, !summary.isEmpty {
                    Divider().padding(.top, 4)
                    Text("Как рассчитан план")
                        .font(.headline)
                        .padding(.top, 4)
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f кг", value)
        }
        return String(format: "%.1f кг", value)
    }

    private func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
