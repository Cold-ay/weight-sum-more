import SwiftUI
import SwiftData

struct HealthImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let profile: UserProfile
    @Query private var exercises: [ExerciseEntry]
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var records: [HealthWorkoutRecord] = []
    @State private var selected: Set<UUID> = []
    @State private var categories: [UUID: ExerciseCategory] = [:]
    @State private var loading = false
    @State private var importing = false
    @State private var loaded = false
    @State private var limit = 20
    @State private var result: HealthImportResult?
    @State private var errorMessage: String?

    init(profile: UserProfile, initialRecords: [HealthWorkoutRecord] = []) {
        self.profile = profile
        _records = State(initialValue: initialRecords)
        _loaded = State(initialValue: !initialRecords.isEmpty)
        if let start = initialRecords.map(\.startDate).min(), let end = initialRecords.map(\.startDate).max() {
            _startDate = State(initialValue: start)
            _endDate = State(initialValue: end)
        }
    }

    private func imported(_ record: HealthWorkoutRecord) -> Bool { exercises.contains { $0.healthWorkoutUUID == record.id.uuidString } }
    private func possibleDuplicate(_ record: HealthWorkoutRecord) -> Bool { WorkoutImportService.likelyDuplicate(record, among: exercises) }
    private func category(_ record: HealthWorkoutRecord) -> ExerciseCategory? { categories[record.id] ?? record.suggestedCategory }
    private var needsCategory: Bool { records.contains { selected.contains($0.id) && category($0) == nil } }

    var body: some View {
        NavigationStack {
            VitalityScreen(title: "Import from Health", subtitle: "Apple Watch workouts appear after syncing with Health. Read-only access; nothing is written back.") {
                VStack(spacing: 14) {
                    VitalityCard {
                        VStack(spacing: 12) {
                            DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            DatePicker("Through", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                        }
                        .tint(VitalityTheme.primary)
                        .disabled(loading || importing)
                    }
                    if HealthWorkoutService.isAvailable {
                        Button { Task { await load() } } label: {
                            HStack {
                                if loading { ProgressView() }
                                Label("Read workouts", systemImage: "heart.text.square")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .disabled(loading || importing)
                        .tint(VitalityTheme.primary)
                    } else {
                        Text("Health data is not available on this device.")
                            .font(.subheadline).foregroundStyle(VitalityTheme.textMuted)
                    }
                    if loaded && records.isEmpty {
                        VitalityCard {
                            EmptyStateView(title: "No readable workouts", message: "There may be no synced workouts in these dates, or Health read access may be off. Check access in the Health app.")
                        }
                    }
                    if !records.isEmpty {
                        HStack {
                            Text(L10n.format("%ld workouts found", records.count)).font(.subheadline)
                            Spacer()
                            Button("Select new") { selectNew() }.font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(VitalityTheme.textMuted)
                        ForEach(Array(records.prefix(limit))) { record in
                            workoutRow(record)
                        }
                        if limit < records.count { Button("Show 20 more") { limit += 20 } }
                        if needsCategory {
                            Text("Choose a category for each selected workout before importing.")
                                .font(.footnote).foregroundStyle(VitalityTheme.warning)
                        }
                        VitalityPrimaryButton(title: L10n.format("Import %ld workouts", selected.count), systemImage: "square.and.arrow.down") {
                            Task { @MainActor in
                                importing = true
                                await Task.yield()
                                importSelected()
                                importing = false
                            }
                        }
                        .disabled(selected.isEmpty || needsCategory || loading || importing)
                        .opacity(selected.isEmpty || needsCategory ? 0.5 : 1)
                    }
                    if let result {
                        Label(L10n.format("Imported %ld; skipped %ld duplicates.", result.imported, result.skipped), systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(VitalityTheme.success)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(importing) }
            }
            .onChange(of: startDate) { _, _ in reset() }
            .onChange(of: endDate) { _, _ in reset() }
            .alert("Health import", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .preferredColorScheme(.dark)
    }

    private func workoutRow(_ record: HealthWorkoutRecord) -> some View {
        let alreadyImported = imported(record)
        let duplicate = !alreadyImported && possibleDuplicate(record)
        return VitalityCard {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(get: { selected.contains(record.id) }, set: { value in
                    if value { selected.insert(record.id) } else { selected.remove(record.id) }
                })) {
                    Text(record.activityName.localized).font(.headline)
                }
                .disabled(alreadyImported || importing)
                .tint(VitalityTheme.primary)
                Text(L10n.date(record.startDate, includeTime: true))
                    .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                Text(L10n.format("%@ · %@", L10n.format("%ld min", record.minutes), record.energyKcal?.caloriesText ?? "Energy unavailable".localized))
                    .font(.subheadline).foregroundStyle(VitalityTheme.text)
                Text(L10n.format("Source: %@", record.sourceName)).font(.caption).foregroundStyle(VitalityTheme.textMuted)
                if alreadyImported {
                    Label("Already imported", systemImage: "checkmark.circle").font(.caption).foregroundStyle(VitalityTheme.success)
                } else {
                    Picker("Training category", selection: Binding<ExerciseCategory?>(get: { category(record) }, set: { value in
                        categories[record.id] = value
                    })) {
                        Text("Choose category").tag(ExerciseCategory?.none)
                        ForEach(ExerciseCategory.allCases) { Text($0.displayName).tag(Optional($0)) }
                    }
                    .tint(VitalityTheme.primary)
                    if duplicate {
                        Text("Possible duplicate. Select only if this is a different session.")
                            .font(.footnote).foregroundStyle(VitalityTheme.warning)
                    }
                }
            }
        }
    }

    private func reset() { records = []; selected = []; loaded = false; result = nil }
    private func selectNew() {
        selected = Set(records.filter { !imported($0) && !possibleDuplicate($0) && category($0) != nil }.map(\.id))
    }
    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let service = HealthWorkoutService()
            try await service.requestReadAccess()
            let calendar = Calendar.current
            let end = min(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate, Date())
            records = try await service.workouts(from: calendar.startOfDay(for: startDate), through: end)
            categories = [:]
            result = nil
            limit = 20
            loaded = true
            selectNew()
        } catch {
            errorMessage = (error as? HealthImportError)?.localizedDescription
                ?? "Could not read Health data. Check Health access and try again.".localized
        }
    }
    private func importSelected() {
        do {
            let chosen = records.filter { selected.contains($0.id) }
            result = try WorkoutImportService.importRecords(chosen, categories: categories,
                allowPossibleDuplicates: Set(chosen.filter { possibleDuplicate($0) }.map(\.id)), profile: profile, in: context)
            selected = []
        } catch { errorMessage = error.localizedDescription }
    }
}
