import SwiftUI
import SwiftData

struct CaloriesLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.trackingDate) private var currentDate
    let profile: UserProfile
    @Query(sort: \CalorieIntakeEntry.date, order: .reverse) private var intakes: [CalorieIntakeEntry]
    @State private var editedEntry: CalorieIntakeEntry?
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var selectedPeriod: AnalyticsPeriod = .thirtyDays
    @State private var selectedMeal: MealCategory?
    @State private var newMeal: MealCategory = .breakfast

    var body: some View {
        let periodEntries = intakes.filter {
            DateHelpers.isWithin($0.date, period: selectedPeriod, endingAt: currentDate)
        }
        let filteredIntakes = periodEntries.filter { selectedMeal == nil || $0.mealCategory == selectedMeal }
        let insights = MealInsights(entries: filteredIntakes)
        let bucket = TrendBucket.choose(period: selectedPeriod, dates: periodEntries.map(\.date))
        let points = PeriodTrends.nutrition(periodEntries, bucket: bucket, meal: selectedMeal)

        NavigationStack {
            VitalityScreen(title: "Nutrition", subtitle: "Meals add up automatically. Follow your intake over time.", trailingSystemImage: "fork.knife") {
                VStack(spacing: 14) {
                    VitalityPrimaryButton(title: "Add intake", systemImage: "plus") {
                        newMeal = MealCategory.suggested(at: currentDate)
                        isAdding = true
                    }
                    HStack(spacing: 8) {
                        ForEach(MealCategory.entryCategories) { meal in
                            Button {
                                newMeal = meal
                                isAdding = true
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: meal.systemImage).font(.title3)
                                    Text(meal.displayName).font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(VitalityTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(VitalityTheme.warning)
                        }
                    }
                    AnalyticsPeriodPicker(selection: $selectedPeriod)
                    LogCategoryFilter(options: MealCategory.entryCategories, selection: $selectedMeal, title: { $0.displayName })
                    LogInsightStrip(items: [
                        ("Daily average", insights.average?.caloriesText ?? "--"),
                        ("Logged days", "\(insights.days.count)")
                    ], tint: VitalityTheme.warning)
                    PeriodBarChart(points: points, bucket: bucket, unit: "kcal",
                                   series: [
                                    (MealCategory.breakfast.rawValue, MealCategory.breakfast.displayName, VitalityTheme.warning),
                                    (MealCategory.lunch.rawValue, MealCategory.lunch.displayName, VitalityTheme.success),
                                    (MealCategory.dinner.rawValue, MealCategory.dinner.displayName, VitalityTheme.primary),
                                    (MealCategory.snack.rawValue, MealCategory.snack.displayName, Color.pink),
                                    (MealCategory.dailyTotal.rawValue, "Unitemized estimate".localized, VitalityTheme.textMuted)
                                   ])
                    if selectedMeal == nil && periodEntries.contains(where: { $0.mealCategory == .dailyTotal }) {
                        Text("Previous daily estimates remain a baseline. Meals itemize that estimate; daily totals update automatically.")
                            .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                    }
                    if !filteredIntakes.isEmpty {
                        RecordDetails(count: filteredIntakes.count) { limit in
                            ForEach(MealInsights(entries: Array(filteredIntakes.prefix(limit))).days) { day in
                                HStack {
                                    Text(L10n.date(day.date)).font(.headline)
                                    Spacer()
                                    Text(IntakeAggregation.total(filteredIntakes.filter {
                                        DateHelpers.isSameDay($0.date, day.date)
                                    }).caloriesText)
                                        .font(.subheadline).monospacedDigit()
                                }
                                .foregroundStyle(VitalityTheme.textMuted)
                                .padding(.top, 8)
                                ForEach(day.entries) { entry in intakeRow(entry) }
                            }
                        }
                        .id("\(selectedPeriod.rawValue)-\(selectedMeal?.rawValue ?? "all")")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                CalorieEditorView(entry: nil, profile: profile, initialMeal: newMeal).preferredColorScheme(.dark)
            }
            .sheet(item: $editedEntry) { entry in
                CalorieEditorView(entry: entry, profile: profile).preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
            .alert("Couldn’t update calories", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check the calorie value and try again."))
            }
        }
    }

    private func intakeRow(_ entry: CalorieIntakeEntry) -> some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        VitalitySectionLabel(text: entry.mealCategory.displayName)
                        Text(entry.calories.caloriesText)
                            .font(.title2.bold())
                            .foregroundStyle(VitalityTheme.warning)
                    }
                    Spacer()
                    Image(systemName: entry.mealCategory.systemImage)
                        .foregroundStyle(VitalityTheme.primary)
                }

                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.footnote)
                        .foregroundStyle(VitalityTheme.textMuted)
                }

                HStack {
                    Button("Edit") { editedEntry = entry }
                    Spacer()
                    Button(role: .destructive) {
                        do {
                            try FitnessDataService.deleteCalorieIntake(entry, profile: profile, in: modelContext)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    } label: {
                        Text("Delete")
                    }
                }
                .font(.caption.weight(.bold))
                .tint(VitalityTheme.primary)
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct CalorieEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: CalorieIntakeEntry?
    let profile: UserProfile
    var initialMeal: MealCategory = .breakfast
    @State private var date = Date()
    @State private var caloriesText = ""
    @State private var mealCategory: MealCategory = .breakfast
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var showingCalorieGuide = false
    @State private var useFoodBuilder = true
    @State private var foodSummary = ""

    var body: some View {
        NavigationStack {
            VitalityScreen(title: entry == nil ? "Add Calories" : "Edit Calories") {
                VStack(spacing: 14) {
                    VitalityCard {
                        VStack(spacing: 12) {
                            Picker("Meal", selection: $mealCategory) {
                                ForEach(entry?.mealCategory == .dailyTotal ? [.dailyTotal] + MealCategory.entryCategories : MealCategory.entryCategories) { meal in
                                    Label(meal.displayName, systemImage: meal.systemImage).tag(meal)
                                }
                            }
                            .tint(VitalityTheme.warning)
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .colorScheme(.dark)
                                .tint(VitalityTheme.primary)
                        }
                    }
                    Picker("Calorie input", selection: $useFoodBuilder) {
                        Text("Food portions").tag(true)
                        Text("Manual total").tag(false)
                    }.pickerStyle(.segmented)
                    Button { showingCalorieGuide = true } label: {
                        Label("Learn to estimate portions", systemImage: "book.closed")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.tint(VitalityTheme.primary)
                    FoodPortionCalculator { calories, summary in
                        caloriesText = String(format: "%.0f", calories)
                        foodSummary = summary
                    }
                    .frame(height: useFoodBuilder ? nil : 0)
                    .clipped()
                    .allowsHitTesting(useFoodBuilder)
                    .accessibilityHidden(!useFoodBuilder)
                    VitalityTextField(title: "Calories", unit: "kcal", text: $caloriesText, keyboardType: .decimalPad)
                    if !foodSummary.isEmpty {
                        Text(foodSummary)
                            .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VitalityTextField(title: "Notes", unit: nil, text: $notes)

                    VitalityPrimaryButton(title: "Save Calories", systemImage: "checkmark") {
                        save()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: loadEntry)
            .sheet(isPresented: $showingCalorieGuide) {
                FoodCalorieGuideView()
            }
            .alert("Couldn’t save calories", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check the calorie value and try again."))
            }
        }
    }

    private func loadEntry() {
        mealCategory = entry?.mealCategory ?? initialMeal
        guard let entry else { return }
        useFoodBuilder = false
        date = entry.date
        caloriesText = String(entry.calories)
        notes = entry.notes
    }

    private func save() {
        guard let calories = Double(caloriesText) else {
            errorMessage = "Enter a numeric calorie value."
            return
        }
        do {
            try FitnessDataService.saveCalorieIntake(
                profile: profile,
                entry: entry,
                date: date,
                calories: calories,
                notes: [notes, foodSummary].filter { !$0.isEmpty }.joined(separator: "\n"),
                mealCategory: mealCategory,
                in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

}
