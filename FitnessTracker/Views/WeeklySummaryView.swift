import SwiftUI
import SwiftData
import Charts

enum EnergyReportSection: String, CaseIterable, Identifiable {
    case balance, comparison, weightEstimate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .balance: "Energy balance".localized
        case .comparison: "Intake vs output".localized
        case .weightEstimate: "Calorie-based weight estimate".localized
        }
    }
    var systemImage: String {
        switch self {
        case .balance: "equal.circle"
        case .comparison: "chart.xyaxis.line"
        case .weightEstimate: "scalemass"
        }
    }
}

struct WeeklySummaryView: View {
    @Environment(\.trackingDate) private var currentDate
    let profile: UserProfile
    let section: EnergyReportSection
    @Query(sort: \ExerciseEntry.date, order: .reverse) private var exercises: [ExerciseEntry]
    @Query(sort: \CalorieIntakeEntry.date, order: .reverse) private var intakes: [CalorieIntakeEntry]
    @Query(sort: \DailyLog.date, order: .reverse) private var dailyLogs: [DailyLog]
    @State private var selectedPeriod: AnalyticsPeriod = .thirtyDays

    var body: some View {
        let model = CalorieAnalyticsViewModel(profile: profile, exercises: exercises, intakes: intakes,
                                             dailyLogs: dailyLogs, period: selectedPeriod, endingAt: currentDate)
        let points = model.points
        let bucket = TrendBucket.choose(period: selectedPeriod, dates: points.map(\.date))
        let chartPoints = PeriodTrends.energy(points, bucket: bucket)
        let status = HealthCalculationService.balanceStatus(for: model.totalBalance / Double(max(points.count, 1)))
        let weight = profile.usesMetricUnits ? model.estimatedWeightChangeKg : UnitConversionService.convertKgToLb(model.estimatedWeightChangeKg)

        VitalityScreen(title: section.title, trailingSystemImage: section.systemImage) {
            VStack(spacing: 14) {
                AnalyticsPeriodPicker(selection: $selectedPeriod)
                if points.isEmpty {
                    VitalityCard {
                        EmptyStateView(title: "No intake logged", message: "Log calorie intake to compare energy in and out for this period.")
                    }
                } else {
                    switch section {
                    case .balance:
                        VitalityProgressCard(
                            title: L10n.format("%@ balance", selectedPeriod.shortLabel),
                            value: signedCalories(model.totalBalance),
                            caption: L10n.format("Based on %ld logged days.", points.count),
                            progress: min(abs(model.totalBalance) / max(model.totalOutput, 1), 1),
                            tint: status.color
                        )
                        LogInsightStrip(items: [("Calories in", model.totalIntake.caloriesText), ("Calories out", model.totalOutput.caloriesText)])
                    case .comparison:
                        VitalityCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VitalitySectionLabel(text: bucket.title)
                                    Spacer()
                                    ChartLegendItem(color: VitalityTheme.warning, title: "In")
                                    ChartLegendItem(color: VitalityTheme.primary, title: "Out")
                                }
                                Chart(chartPoints) { point in
                                    LineMark(x: .value("Date", point.date), y: .value("Calories", point.calorieIntake),
                                             series: .value("Flow", "Intake"))
                                        .foregroundStyle(VitalityTheme.warning).symbol(.circle)
                                    LineMark(x: .value("Date", point.date), y: .value("Calories", point.calorieOutput),
                                             series: .value("Flow", "Output"))
                                        .foregroundStyle(VitalityTheme.primary).symbol(.circle)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 4)) {
                                        AxisValueLabel(format: .dateTime.month(.abbreviated).day().locale(L10n.locale))
                                    }
                                }
                                .frame(height: 260)
                                Text(L10n.format("Based on %ld logged days.", points.count))
                                    .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                            }
                        }
                    case .weightEstimate:
                        MetricCard(title: "Estimated weight change",
                                   value: weight.weightText(unit: profile.usesMetricUnits ? "kg" : "lb"),
                                   detail: "Uses 7700 kcal per kg as a rough approximation.", systemImage: "scalemass")
                        Text("Real body weight can fluctuate due to water, digestion, hormones, and measurement timing.")
                            .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                        Text(L10n.format("Based on %ld logged days.", points.count))
                            .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func signedCalories(_ value: Double) -> String { "\(value > 0 ? "+" : "")\(value.caloriesText)" }
}
