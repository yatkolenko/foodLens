import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: FoodStore
    @State private var selectedDay = Date.startOfToday
    @State private var entryPendingDeletion: FoodEntry?
    @State private var showingQuickVoiceAdd = false

    private var profile: UserProfile? {
        store.profile
    }

    private var totals: (kcal: Double, protein: Double, carbs: Double, fat: Double) {
        store.totals(for: selectedDay)
    }

    private var isShowingEntryDeletionDialog: Binding<Bool> {
        Binding(
            get: { entryPendingDeletion != nil },
            set: { newValue in
                if !newValue {
                    entryPendingDeletion = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            dateStrip
                            customDateCard
                            dailySummaryCard(profile)
                            rationSection
                            waterCard(profile)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 88)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        VStack(spacing: 12) {
                            NavigationLink {
                                AddMealView(day: selectedDay, mealType: .lunch)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(DesignTokens.textPrimary)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(DesignTokens.cardElevated)
                                            .overlay(
                                                Circle()
                                                    .stroke(DesignTokens.cardStroke, lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: DesignTokens.cardShadow.opacity(0.85), radius: 8, x: 0, y: 4)
                            }

                            Button {
                                showingQuickVoiceAdd = true
                            } label: {
                                Image(systemName: "mic.fill")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Circle().fill(DesignTokens.floatingActionBackground))
                                    .shadow(color: DesignTokens.cardShadow.opacity(0.9), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                    }
                } else {
                    ContentUnavailableView(
                        "Профиль сброшен",
                        systemImage: "person.crop.circle.badge.xmark",
                        description: Text("Возвращаемся к настройке профиля.")
                    )
                    .padding(.horizontal, 16)
                }
            }
            .background(DesignTokens.background)
            .navigationTitle("Обзор")
            .confirmationDialog(
                "Удалить запись?",
                isPresented: isShowingEntryDeletionDialog,
                titleVisibility: .visible,
                presenting: entryPendingDeletion
            ) { entry in
                Button("Удалить", role: .destructive) {
                    store.deleteEntry(id: entry.id)
                    entryPendingDeletion = nil
                }
                Button("Отмена", role: .cancel) {
                    entryPendingDeletion = nil
                }
            } message: { entry in
                Text("«\(entry.analysis.foodName)» будет удалено из дневника.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(shortDate(selectedDay))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            .sheet(isPresented: $showingQuickVoiceAdd) {
                NavigationStack {
                    QuickVoiceMealView(day: selectedDay)
                }
            }
        }
    }

    private var dateStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(dayRange, id: \.self) { day in
                    let sel = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                    Button {
                        selectedDay = day.startOfDay
                    } label: {
                        VStack(spacing: 4) {
                            Text(weekdayShort(day))
                                .font(.caption2)
                                .foregroundStyle(sel ? .white : DesignTokens.textSecondary)
                            Text("\(Calendar.current.component(.day, from: day))")
                                .font(.headline)
                                .foregroundStyle(sel ? .white : DesignTokens.textPrimary)
                        }
                        .frame(width: 48, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(sel ? DesignTokens.accentGreen : DesignTokens.cardElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(sel ? Color.clear : DesignTokens.cardStroke, lineWidth: 1)
                                )
                                .shadow(color: DesignTokens.cardShadow, radius: 6, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var dayRange: [Date] {
        let cal = Calendar.current
        return (-6...0).compactMap { cal.date(byAdding: .day, value: $0, to: Date()) }
            .map { $0.startOfDay }
    }

    private var customDateCard: some View {
        CardView {
            HStack(spacing: 12) {
                Label("Выбранный день", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                DatePicker(
                    "Дата",
                    selection: selectedDayBinding,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ru_RU"))
            }
        }
    }

    private func dailySummaryCard(_ profile: UserProfile) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Итоги дня")
                        .font(.headline)
                    Spacer()
                    Text(shortDate(selectedDay))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    summaryTile(title: "Калории", used: totals.kcal, target: profile.targetCaloriesKcalPerDay, unit: "ккал")
                    summaryTile(title: "Белок", used: totals.protein, target: profile.targetProteinGPerDay, unit: "г")
                    summaryTile(title: "Углеводы", used: totals.carbs, target: profile.targetCarbsGPerDay, unit: "г")
                    summaryTile(title: "Жиры", used: totals.fat, target: profile.targetFatGPerDay, unit: "г")
                }
            }
        }
    }

    private func summaryTile(title: String, used: Double, target: Double, unit: String) -> some View {
        let remaining = target - used
        let isOverTarget = remaining < 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()
                circularProgressBadge(used: used, target: target, isOverTarget: isOverTarget)
            }

            Text("\(Int(used.rounded())) / \(Int(target.rounded())) \(unit)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(
                remaining >= 0
                ? "Осталось \(Int(remaining.rounded(.down))) \(unit)"
                : "Перебор \(Int(abs(remaining).rounded(.up))) \(unit)"
            )
            .font(.caption)
            .foregroundStyle(remaining >= 0 ? DesignTokens.textSecondary : .orange)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignTokens.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DesignTokens.cardStroke, lineWidth: 1)
                )
                .shadow(color: DesignTokens.cardShadow, radius: 8, x: 0, y: 2)
        )
    }

    private func pct(_ cur: Double, _ target: Double) -> Int {
        guard target > 0 else { return 0 }
        return min(999, Int((cur / target) * 100))
    }

    private func circularProgressBadge(used: Double, target: Double, isOverTarget: Bool) -> some View {
        let progress = target > 0 ? min(max(used / target, 0), 1) : 0
        let accent = isOverTarget ? Color.orange : DesignTokens.accentYellow

        return ZStack {
            Circle()
                .fill(accent.opacity(0.16))

            Circle()
                .stroke(DesignTokens.cardStroke, lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(pct(used, target))%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.horizontal, 4)
        }
        .frame(width: 42, height: 42)
    }

    private var rationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Рацион")
                    .font(.title3.bold())
                Spacer()
            }

            ForEach(MealType.rationOrder) { meal in
                mealBlock(meal)
            }
        }
    }

    private func mealBlock(_ meal: MealType) -> some View {
        let items = store.entries(for: selectedDay, meal: meal)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: meal.systemImage)
                    .foregroundStyle(DesignTokens.accentGreen)
                Text(meal.title)
                    .font(.headline)
                Spacer()
                NavigationLink {
                    AddMealView(day: selectedDay, mealType: meal)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.accentGreen)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignTokens.surfaceSoftGreen)
            )

            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { entry in
                        NavigationLink {
                            AddMealView(day: entry.consumptionDate, mealType: entry.mealType, entry: entry)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.analysis.foodName)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(Int(entry.analysis.caloriesKcal)) ккал · Б \(Int(entry.analysis.proteinG)) · У \(Int(entry.analysis.carbsG)) · Ж \(Int(entry.analysis.fatG))")
                                        .font(.caption)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                    if let weight = entry.weightGrams {
                                        Text("Порция: \(formattedWeight(weight)) г")
                                            .font(.caption2)
                                            .foregroundStyle(DesignTokens.textSecondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(entryTime(entry.consumptionDate))
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                entryPendingDeletion = entry
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                entryPendingDeletion = entry
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }

                        if entry.id != items.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DesignTokens.cardElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(DesignTokens.cardStroke, lineWidth: 1)
                        )
                )
                .offset(y: -6)
            }
        }
    }

    private func waterCard(_ profile: UserProfile) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.blue)
                    Text("Вода")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            store.addWater(-0.25, on: selectedDay)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        Button {
                            store.addWater(0.25, on: selectedDay)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                let w = store.waterLiters(on: selectedDay)
                let goal = profile.targetWaterLitersPerDay
                Text(String(format: "%.1f л из %.1f л", w, goal))
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.textSecondary)
                ProgressView(value: min(w, goal), total: max(goal, 0.1))
                    .tint(.blue)
            }
        }
    }

    private func weekdayShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EE"
        return String(f.string(from: d).prefix(2)).uppercased()
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d.MM"
        return f.string(from: d)
    }

    private func entryTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private func formattedWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var selectedDayBinding: Binding<Date> {
        Binding(
            get: { selectedDay },
            set: { selectedDay = $0.startOfDay }
        )
    }
}

private extension Date {
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }
}
