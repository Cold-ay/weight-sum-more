import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile
    @Query(sort: \ExerciseEntry.date, order: .reverse) private var exercises: [ExerciseEntry]
    @Query(sort: \CalorieIntakeEntry.date, order: .reverse) private var intakes: [CalorieIntakeEntry]
    @Query(sort: \DailyLog.date, order: .reverse) private var dailyLogs: [DailyLog]
    @Query(sort: \MonthlyGoal.updatedAt, order: .reverse) private var monthlyGoals: [MonthlyGoal]
    @Environment(\.trackingDate) private var currentDate
    @State private var isEditingMonthlyGoal = false

    var body: some View {
        let viewModel = DashboardViewModel(profile: profile, exercises: exercises, intakes: intakes, dailyLogs: dailyLogs, date: currentDate)
        let balance = viewModel.energyBalance

        NavigationStack {
            VitalityScreen(
                title: "Today",
                subtitle: "Your daily energy, activity, and progress at a glance.",
                trailingSystemImage: "bolt.heart"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    DisclaimerBanner(isCaution: profile.needsHealthDisclaimer)

                    CharacterProgressCard(
                        sex: profile.sex,
                        progress: viewModel.characterProgress(monthlyGoal: currentMonthlyGoal),
                        activity: viewModel.characterActivity
                    )

                    motivationCard(message: viewModel.motivationMessage(monthlyGoal: currentMonthlyGoal))

                    MonthlyGoalCard(
                        goal: currentMonthlyGoal,
                        exercises: exercises,
                        date: currentDate
                    ) {
                        isEditingMonthlyGoal = true
                    }

                    VitalityProgressCard(
                        title: "Daily Balance",
                        value: signedCalories(balance.dailyBalance),
                        caption: L10n.format("%@: intake minus estimated output.", balance.status.displayName),
                        progress: balanceProgress(balance),
                        tint: balance.status.color
                    )

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        MetricCard(
                            title: "BMR/RMR",
                            value: viewModel.bmrResult.value.caloriesText,
                            detail: L10n.format("Estimated with %@.", viewModel.bmrResult.mode.displayName),
                            systemImage: "flame"
                        )
                        MetricCard(
                            title: "TDEE",
                            value: balance.tdee.caloriesText,
                            detail: L10n.format("BMR × %.3g + exercise.", profile.activityLevel.factor),
                            systemImage: "gauge.with.dots.needle.50percent"
                        )
                        MetricCard(
                            title: "Calories in",
                            value: balance.calorieIntake.caloriesText,
                            detail: "Logged food energy today.",
                            tint: VitalityTheme.warning,
                            systemImage: "fork.knife"
                        )
                        MetricCard(
                            title: "Exercise",
                            value: balance.exerciseCalories.caloriesText,
                            detail: "Logged exercise energy today.",
                            tint: VitalityTheme.success,
                            systemImage: "figure.run"
                        )
                    }

                    VitalityCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VitalitySectionLabel(text: "Metabolic Snapshot")
                            HStack {
                                snapshotItem("Goal", profile.fitnessGoal.displayName)
                                Divider().background(VitalityTheme.outline)
                                snapshotItem("Activity", profile.activityLevel.displayName)
                            }
                            .frame(minHeight: 58)
                        }
                    }
                }
            }
            .sheet(isPresented: $isEditingMonthlyGoal) {
                MonthlyGoalEditorView(goal: currentMonthlyGoal, month: currentDate)
                    .preferredColorScheme(.dark)
            }
            .preferredColorScheme(.dark)
            .task(id: DateHelpers.startOfDay(currentDate)) { synchronizeToday() }
        }
    }

    private var currentMonthlyGoal: MonthlyGoal? {
        monthlyGoals.first {
            Calendar.current.isDate($0.month, equalTo: currentDate, toGranularity: .month)
        }
    }

    private func motivationCard(message: String) -> some View {
        VitalityCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: profile.fitnessGoal.systemImage)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(VitalityTheme.primary)
                        .frame(width: 38, height: 38)
                        .background(VitalityTheme.primary.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        VitalitySectionLabel(text: "Tough love coach")
                        Text(profile.fitnessGoal.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VitalityTheme.text)
                    }

                    Spacer()

                }

                Text(L10n.text(message))
                    .font(.body)
                    .lineSpacing(5)
                    .foregroundStyle(VitalityTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(L10n.format("Daily motivation: %@", message))
            }
        }
    }

    private func signedCalories(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(value.caloriesText)"
    }

    private func balanceProgress(_ balance: EnergyBalanceResult) -> Double {
        guard balance.tdee > 0 else { return 0 }
        return min(abs(balance.dailyBalance) / balance.tdee, 1)
    }

    private func snapshotItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(label))
                .font(.caption.weight(.medium))
                .foregroundStyle(VitalityTheme.textMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VitalityTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func synchronizeToday() {
        _ = try? FitnessDataService.upsertDailyLog(for: currentDate, profile: profile, in: modelContext)
    }
}
