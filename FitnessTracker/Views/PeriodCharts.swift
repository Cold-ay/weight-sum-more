import SwiftUI
import Charts

struct PeriodBarChart: View {
    let points: [PeriodTrendPoint]
    let bucket: TrendBucket
    let unit: String
    let series: [(String, String, Color)]
    @State private var selectedDate: Date?

    var body: some View {
        let visibleSeries = series.filter { item in points.contains { $0.series == item.0 } }
        VitalityCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VitalitySectionLabel(text: bucket.title)
                    Spacer()
                    Text(L10n.text(unit)).font(.caption).foregroundStyle(VitalityTheme.textMuted)
                }
                if points.isEmpty {
                    EmptyStateView(title: "No records in this period", message: "Add a record or choose another period.")
                } else {
                    Chart {
                        ForEach(points) { point in
                            BarMark(x: .value("Date", point.date, unit: bucket.component), y: .value(unit, point.value))
                                .foregroundStyle(by: .value("Category", series.first { $0.0 == point.series }?.1 ?? point.series))
                        }
                        if let selectedDate {
                            RuleMark(x: .value("Date", bucket.start(selectedDate)))
                                .foregroundStyle(VitalityTheme.textMuted.opacity(0.5))
                                .lineStyle(StrokeStyle(dash: [4]))
                        }
                    }
                    .chartForegroundStyleScale(domain: visibleSeries.map(\.1), range: visibleSeries.map(\.2))
                    .chartXSelection(value: $selectedDate)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day().locale(L10n.locale))
                            AxisGridLine().foregroundStyle(VitalityTheme.outline)
                        }
                    }
                    .chartLegend(position: .bottom, alignment: .leading)
                    .frame(height: 220)
                    if let selectedDate {
                        let matching = points.filter { $0.date == bucket.start(selectedDate) }
                        if !matching.isEmpty {
                            Text(L10n.format("%@: %@ %@", L10n.date(bucket.start(selectedDate)),
                                             matching.reduce(0) { $0 + $1.value }.formatted(.number.precision(.fractionLength(0...1)).locale(L10n.locale)),
                                             L10n.text(unit)))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(VitalityTheme.primary)
                        }
                    }
                }
            }
        }
        .onChange(of: points.map(\.id)) { _, _ in selectedDate = nil }
    }
}

struct WeightPeriodChart: View {
    let entries: [WeightEntry]
    let allEntries: [WeightEntry]
    let period: AnalyticsPeriod
    let usesMetricUnits: Bool
    @State private var showAverage = true
    @State private var selectedDate: Date?

    private var bucket: TrendBucket { .choose(period: period, dates: entries.map(\.date)) }
    private var points: [WeightAveragePoint] {
        if showAverage {
            return PeriodTrends.weight(WeightInsights(entries: entries, allEntries: allEntries).averagePoints, bucket: bucket)
        }
        let grouped = Dictionary(grouping: entries, by: { bucket == .day ? $0.date : DateHelpers.startOfDay($0.date) })
        let daily = grouped.map { date, values in
            WeightAveragePoint(date: date, weightKg: values.reduce(0) { $0 + $1.weightKg } / Double(values.count))
        }.sorted { $0.date < $1.date }
        return bucket == .day ? daily : PeriodTrends.weight(daily, bucket: bucket)
    }
    private func display(_ kg: Double) -> Double { usesMetricUnits ? kg : UnitConversionService.convertKgToLb(kg) }

    var body: some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VitalitySectionLabel(text: "Weight Trend")
                    Spacer()
                    Text(bucket.title).font(.caption).foregroundStyle(VitalityTheme.textMuted)
                }
                Picker("Trend style", selection: $showAverage) {
                    Text("Recorded trend").tag(false)
                    Text("7-day average").tag(true)
                }
                .pickerStyle(.segmented)
                if points.isEmpty {
                    EmptyStateView(title: "No records in this period", message: "Add a record or choose another period.")
                } else {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Weight", display(point.weightKg)))
                            .foregroundStyle(VitalityTheme.primary)
                            .symbol(.circle)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXSelection(value: $selectedDate)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day().locale(L10n.locale))
                            AxisGridLine().foregroundStyle(VitalityTheme.outline)
                        }
                    }
                    .frame(height: 220)
                    if let selectedDate,
                       let nearest = points.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }) {
                        Text(L10n.format("%@: %@", L10n.date(nearest.date), display(nearest.weightKg).weightText(unit: usesMetricUnits ? "kg" : "lb")))
                            .font(.subheadline.weight(.medium)).foregroundStyle(VitalityTheme.primary)
                    }
                }
            }
        }
        .onChange(of: period) { _, _ in selectedDate = nil }
        .onChange(of: showAverage) { _, _ in selectedDate = nil }
    }
}

struct RecordDetails<Content: View>: View {
    let count: Int
    let content: (Int) -> Content
    @State private var expanded = false
    @State private var limit = 10

    init(count: Int, @ViewBuilder content: @escaping (Int) -> Content) {
        self.count = count
        self.content = content
    }
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            LazyVStack(spacing: 12) {
                content(limit)
                if limit < count {
                    Button("Show 10 more") { limit += 10 }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }.padding(.top, 12)
        } label: {
            HStack {
                Text("Record details")
                Spacer()
                Text("\(count)").monospacedDigit().foregroundStyle(VitalityTheme.textMuted)
            }.font(.subheadline.weight(.semibold))
        }
        .tint(VitalityTheme.primary)
        .foregroundStyle(VitalityTheme.text)
    }
}

struct WeightRecordingProgressView: View {
    let profileID: UUID
    let period: AnalyticsPeriod
    let count: Int
    @AppStorage("weightRecordingGoals") private var storedGoals = Data()

    var body: some View {
        if let goal = WeightGoalPreferences.decode(storedGoals).target(profileID: profileID, period: period) {
            VitalityCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VitalitySectionLabel(text: "Your recording goal")
                        Spacer()
                        if count >= goal {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(VitalityTheme.success)
                                .accessibilityLabel("Target complete")
                        }
                    }
                    ProgressView(value: Double(min(count, goal)), total: Double(goal)).tint(VitalityTheme.primary)
                    Text(L10n.format("%ld of %ld records", count, goal))
                        .font(.subheadline).monospacedDigit()
                    Text("Manage in More → Goals")
                        .font(.caption).foregroundStyle(VitalityTheme.textMuted)
                }
            }
        }
    }
}

struct WeightRecordingGoalView: View {
    let profileID: UUID
    let period: AnalyticsPeriod
    let count: Int
    @AppStorage("weightRecordingGoals") private var storedGoals = Data()
    @State private var targetText = ""
    @State private var errorMessage: String?
    private var goal: Int? { WeightGoalPreferences.decode(storedGoals).target(profileID: profileID, period: period) }

    var body: some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 12) {
                VitalitySectionLabel(text: "Your recording goal")
                HStack(spacing: 12) {
                    TextField("Target count", text: $targetText)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Target count")
                        .padding(12)
                        .background(VitalityTheme.secondaryContainer)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button("Save goal", action: save)
                        .font(.subheadline.weight(.semibold))
                        .tint(VitalityTheme.primary)
                    if goal != nil {
                        Button {
                            targetText = ""
                            save()
                        } label: { Image(systemName: "xmark.circle") }
                        .accessibilityLabel("Clear goal")
                        .tint(VitalityTheme.textMuted)
                    }
                }
                if let goal {
                    ProgressView(value: Double(min(count, goal)), total: Double(goal)).tint(VitalityTheme.primary)
                    Text(L10n.format("%ld of %ld records", count, goal))
                        .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                } else {
                    Text(L10n.format("%ld records in this period. Set your own target.", count))
                        .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: period) { _, _ in load() }
        .alert("Couldn’t save goal", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
    private func load() { targetText = goal.map(String.init) ?? "" }
    private func save() {
        do {
            let trimmed = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            let value: Int?
            if trimmed.isEmpty { value = nil }
            else {
                guard let parsed = Int(trimmed) else { throw WeightGoalError.invalidCount }
                value = parsed
            }
            var preferences = WeightGoalPreferences.decode(storedGoals)
            try preferences.set(value, profileID: profileID, period: period)
            storedGoals = try preferences.encoded()
            load()
        } catch { errorMessage = error.localizedDescription }
    }
}
