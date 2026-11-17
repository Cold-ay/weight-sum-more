import SwiftUI
import SwiftData

struct ExerciseLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.trackingDate) private var currentDate
    let profile: UserProfile
    @Query(sort: \ExerciseEntry.date, order: .reverse) private var exercises: [ExerciseEntry]
    @State private var editedEntry: ExerciseEntry?
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var selectedPeriod: AnalyticsPeriod = .thirtyDays
    @State private var selectedCategory: ExerciseCategory?
    @State private var isImportingHealth = false

    var body: some View {
        let filteredExercises = exercises.filter {
            DateHelpers.isWithin($0.date, period: selectedPeriod, endingAt: currentDate)
                && (selectedCategory == nil || $0.trainingCategory == selectedCategory)
        }
        let insights = ExerciseInsights(entries: filteredExercises)
        let bucket = TrendBucket.choose(period: selectedPeriod, dates: filteredExercises.map(\.date))
        let categoryExercises = exercises.filter { selectedCategory == nil || $0.trainingCategory == selectedCategory }
        let streakInsights = ExerciseInsights(entries: categoryExercises)

        NavigationStack {
            VitalityScreen(
                title: "Training",
                subtitle: "Build a rhythm. Explore your training mix.",
                trailingSystemImage: "figure.run"
            ) {
                VStack(spacing: 14) {
                    VitalityPrimaryButton(title: "Add Exercise", systemImage: "plus") {
                        isAdding = true
                    }
                    Button { isImportingHealth = true } label: {
                        Label("Import from Health", systemImage: "heart.text.square")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .tint(VitalityTheme.primary)

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(L10n.format("Current streak: %ld days", streakInsights.currentStreak(endingAt: currentDate)), systemImage: "flame.fill")
                                    .font(.headline).foregroundStyle(VitalityTheme.success)
                                Spacer(minLength: 4)
                            }
                            ActivityWeek(dates: categoryExercises.map(\.date), endingAt: currentDate)
                            Text("If today is not logged yet, the streak ends at yesterday.")
                                .font(.caption).foregroundStyle(VitalityTheme.textMuted)
                        }
                    }

                    AnalyticsPeriodPicker(selection: $selectedPeriod)
                    LogCategoryFilter(options: ExerciseCategory.allCases, selection: $selectedCategory, title: { $0.displayName })

                    LogInsightStrip(items: [
                        ("Workouts", "\(filteredExercises.count)"),
                        ("Active minutes", "\(insights.minutes)"),
                        ("Active days", "\(insights.activeDays)")
                    ], tint: VitalityTheme.success)
                    if filteredExercises.contains(where: \.healthEnergyUnavailable) {
                        Text("Workouts without energy count toward activity, but add no estimated calorie burn.")
                            .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                    }

                    PeriodBarChart(points: PeriodTrends.training(filteredExercises, bucket: bucket), bucket: bucket, unit: "min",
                                   series: [(ExerciseCategory.cardio, VitalityTheme.primary), (.strength, VitalityTheme.success), (.mindAndBody, VitalityTheme.warning)].map {
                        ($0.0.rawValue, $0.0.displayName, $0.1)
                    })
                    Label(L10n.format("Best streak: %ld days", insights.longestStreak), systemImage: "flame")
                        .font(.footnote).foregroundStyle(VitalityTheme.textMuted)

                    if filteredExercises.isEmpty {
                        VitalityCard {
                            EmptyStateView(
                                title: "No exercise in this period",
                                message: "Try another category or time period, or log a workout."
                            )
                        }
                    } else {
                        RecordDetails(count: filteredExercises.count) { limit in
                            ForEach(Array(filteredExercises.prefix(limit))) { entry in exerciseRow(entry) }
                        }
                        .id("\(selectedPeriod.rawValue)-\(selectedCategory?.rawValue ?? "all")")
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                        ExerciseEditorView(entry: nil, profile: profile)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $editedEntry) { entry in
                ExerciseEditorView(entry: entry, profile: profile)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $isImportingHealth) {
                HealthImportView(profile: profile).preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
            .alert("Couldn’t update exercise", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check the exercise values and try again."))
            }
        }
    }

    private func exerciseRow(_ entry: ExerciseEntry) -> some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        VitalitySectionLabel(text: entry.displayName)
                        Text(entry.trainingCategory.displayName)
                            .font(.caption).foregroundStyle(VitalityTheme.textMuted)
                        Text(L10n.format("%ld min", entry.durationMinutes))
                            .font(.title2.bold())
                            .foregroundStyle(VitalityTheme.success)
                    }
                    Spacer()
                    Image(systemName: entry.exerciseType.systemImage)
                        .foregroundStyle(VitalityTheme.primary)
                }

                Text(L10n.format("%@ · %@ · %@", entry.healthEnergyUnavailable ? "Energy unavailable".localized : entry.caloriesBurned.caloriesText,
                                 entry.hasPerceivedEffort ? entry.intensity.displayName : "Effort not supplied".localized,
                                 L10n.date(entry.date, includeTime: true)))
                    .font(.subheadline)
                    .foregroundStyle(VitalityTheme.textMuted)
                if entry.healthWorkoutUUID != nil {
                    Label(L10n.format("Source: %@", entry.healthSourceName), systemImage: "heart.text.square")
                        .font(.caption).foregroundStyle(VitalityTheme.primary)
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
                            try FitnessDataService.deleteExercise(entry, profile: profile, in: modelContext)
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

struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: ExerciseEntry?
    let profile: UserProfile
    @State private var date = Date()
    @State private var exerciseType: ExerciseType = .walking
    @State private var category: ExerciseCategory = .cardio
    @State private var durationText = "30"
    @State private var intensity: ExerciseIntensity = .moderate
    @State private var caloriesText = "150"
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var energyUnavailable = false
    @State private var effortAvailable = true

    var body: some View {
        NavigationStack {
            VitalityScreen(title: entry == nil ? "Add Exercise" : "Edit Exercise") {
                VStack(spacing: 14) {
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VitalitySectionLabel(text: "Training category")
                            Picker("Training category", selection: $category) {
                                ForEach(ExerciseCategory.allCases) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Date and Time")
                            DatePicker("Date and time", selection: $date)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(VitalityTheme.primary)
                        }
                    }

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Exercise Type")
                            Picker("Exercise type", selection: $exerciseType) {
                                ForEach(availableTypes) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(VitalityTheme.primary)
                        }
                    }

                    HStack(spacing: 12) {
                        VitalityTextField(title: "Duration", unit: "min", text: $durationText, keyboardType: .numberPad)
                        VitalityTextField(title: "Calories", unit: "kcal", text: $caloriesText, keyboardType: .decimalPad)
                            .disabled(energyUnavailable)
                    }
                    if entry?.healthWorkoutUUID != nil {
                        Toggle("Energy unavailable", isOn: $energyUnavailable).tint(VitalityTheme.primary)
                        Toggle("Set perceived effort", isOn: $effortAvailable).tint(VitalityTheme.primary)
                    }

                    if effortAvailable {
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Perceived effort")
                            Picker("Perceived effort", selection: $intensity) {
                                ForEach(ExerciseIntensity.allCases) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .tint(VitalityTheme.primary)
                            Text(intensity.effortDescription)
                                .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                        }
                    }
                    }

                    VitalityTextField(title: "Notes", unit: nil, text: $notes)

                    VitalityPrimaryButton(title: "Save Exercise", systemImage: "checkmark") {
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
            .onChange(of: category) { _, _ in
                if !availableTypes.contains(exerciseType) { exerciseType = availableTypes.first ?? .walking }
            }
            .alert("Couldn’t save exercise", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check the exercise values and try again."))
            }
        }
    }

    private func loadEntry() {
        guard let entry else { return }
        category = entry.trainingCategory
        date = entry.date
        exerciseType = entry.exerciseType
        durationText = String(entry.durationMinutes)
        intensity = entry.intensity
        caloriesText = String(entry.caloriesBurned)
        notes = entry.notes
        energyUnavailable = entry.healthEnergyUnavailable
        effortAvailable = entry.hasPerceivedEffort
    }

    private func save() {
        let parsedCalories: Double? = energyUnavailable ? 0 : Double(caloriesText)
        guard let durationMinutes = Int(durationText), let caloriesBurned = parsedCalories else {
            errorMessage = "Enter a whole number of minutes and a numeric calorie value."
            return
        }
        do {
            try FitnessDataService.saveExercise(
                profile: profile,
                entry: entry,
                date: date,
                exerciseType: exerciseType,
                durationMinutes: durationMinutes,
                intensity: intensity,
                caloriesBurned: caloriesBurned,
                notes: notes,
                category: category,
                energyUnavailable: energyUnavailable,
                effortAvailable: effortAvailable,
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

    private var availableTypes: [ExerciseType] {
        let types = ExerciseType.allCases.filter { $0 != .other && $0.category == category }
        return entry?.exerciseType == .other ? types + [.other] : types
    }

}
