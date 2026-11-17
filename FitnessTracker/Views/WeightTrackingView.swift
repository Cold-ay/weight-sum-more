import SwiftUI
import SwiftData
import Charts

struct WeightTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.trackingDate) private var currentDate
    let profile: UserProfile
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var editedEntry: WeightEntry?
    @State private var isAdding = false
    @State private var errorMessage: String?
    @State private var selectedPeriod: AnalyticsPeriod = .thirtyDays

    var body: some View {
        let analytics = WeightAnalyticsViewModel(
            weights: weights, usesMetricUnits: profile.usesMetricUnits, period: selectedPeriod, endingAt: currentDate
        )
        NavigationStack {
            VitalityScreen(title: "Weight", subtitle: "See the trend. Set your own recording rhythm.", trailingSystemImage: "scalemass") {
                VStack(spacing: 14) {
                    VitalityPrimaryButton(title: "Add Weight", systemImage: "plus") { isAdding = true }
                    AnalyticsPeriodPicker(selection: $selectedPeriod)
                    LogInsightStrip(items: [
                        ("Latest weight", analytics.entries.last.map { displayWeight($0.weightKg) } ?? "--"),
                        ("Records", "\(analytics.entries.count)")
                    ])
                    WeightPeriodChart(entries: analytics.entries, allEntries: weights, period: selectedPeriod,
                                      usesMetricUnits: profile.usesMetricUnits)
                    WeightRecordingProgressView(profileID: profile.id, period: selectedPeriod, count: analytics.entries.count)
                    if let change = analytics.displayWeightChange,
                       let first = analytics.entries.first, let last = analytics.entries.last {
                        MetricCard(
                            title: L10n.format("%@ recorded change", selectedPeriod.shortLabel),
                            value: signedWeight(change, unit: analytics.unit),
                            detail: L10n.format("From %@ to %@", L10n.date(first.date), L10n.date(last.date)),
                            tint: VitalityTheme.primary,
                            systemImage: "chart.xyaxis.line"
                        )
                    }
                    if !analytics.entries.isEmpty {
                        RecordDetails(count: analytics.entries.count) { limit in
                            ForEach(Array(analytics.entries.reversed().prefix(limit))) { entry in weightRow(entry) }
                        }
                        .id(selectedPeriod)
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                WeightEditorView(entry: nil, profile: profile).preferredColorScheme(.dark)
            }
            .sheet(item: $editedEntry) { entry in
                WeightEditorView(entry: entry, profile: profile).preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
            .alert("Couldn’t update weight", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check the weight value and try again."))
            }
        }
    }

    private func weightRow(_ entry: WeightEntry) -> some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        VitalitySectionLabel(text: L10n.date(entry.date, includeTime: true))
                        Text(displayWeight(entry.weightKg))
                            .font(.title2.bold())
                            .foregroundStyle(VitalityTheme.primary)
                    }
                    Spacer()
                    Image(systemName: "scalemass")
                        .foregroundStyle(VitalityTheme.primary)
                }

                HStack {
                    Button("Edit") { editedEntry = entry }
                    Spacer()
                    Button(role: .destructive) {
                        do {
                            try FitnessDataService.deleteWeight(entry, profile: profile, in: modelContext)
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

    private func displayWeight(_ weightKg: Double) -> String {
        if profile.usesMetricUnits {
            return weightKg.kgText
        }
        return UnitConversionService.convertKgToLb(weightKg).weightText(unit: "lb")
    }

    private func signedWeight(_ value: Double, unit: String) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(value.weightText(unit: unit))"
    }
}

struct WeightEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: WeightEntry?
    let profile: UserProfile
    @State private var date = Date()
    @State private var weightText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VitalityScreen(title: entry == nil ? "Add Weight" : "Edit Weight") {
                VStack(spacing: 14) {
                    VitalityCard {
                        VStack(alignment: .leading, spacing: 10) {
                            VitalitySectionLabel(text: "Date")
                            DatePicker("Date", selection: $date)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .tint(VitalityTheme.primary)
                        }
                    }

                    VitalityTextField(title: "Weight", unit: profile.usesMetricUnits ? "kg" : "lb", text: $weightText, keyboardType: .decimalPad)

                    VitalityPrimaryButton(title: "Save Weight", systemImage: "checkmark") {
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
            .alert("Couldn’t save weight", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(L10n.text(errorMessage ?? "Please check the weight value and try again."))
            }
        }
    }

    private func loadEntry() {
        date = entry?.date ?? Date()
        let weightKg = entry?.weightKg ?? profile.weightKg
        let displayedWeight = profile.usesMetricUnits ? weightKg : UnitConversionService.convertKgToLb(weightKg)
        weightText = String(format: "%.1f", displayedWeight)
    }

    private func save() {
        guard let weight = Double(weightText) else {
            errorMessage = "Enter a numeric weight value."
            return
        }
        let storedWeight = profile.usesMetricUnits ? weight : UnitConversionService.convertLbToKg(weight)
        do {
            try FitnessDataService.saveWeight(
                profile: profile,
                entry: entry,
                date: date,
                weightKg: storedWeight,
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
