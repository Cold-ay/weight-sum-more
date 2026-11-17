import SwiftUI
import SwiftData

struct MoreView: View {
    let profile: UserProfile
    var body: some View {
        NavigationStack {
            List {
                Section("Energy reports") {
                    ForEach(EnergyReportSection.allCases) { section in
                        NavigationLink {
                            WeeklySummaryView(profile: profile, section: section)
                        } label: {
                            Label(section.title, systemImage: section.systemImage)
                        }
                    }
                }
                Section("Settings") {
                    NavigationLink {
                        GoalsView(profile: profile)
                    } label: {
                        Label("Goals", systemImage: "target")
                    }
                    NavigationLink {
                        SettingsView(profile: profile)
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                }
            }
            .listRowSpacing(4)
            .scrollContentBackground(.hidden)
            .background(VitalityTheme.background)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .tint(VitalityTheme.primary)
        }
        .preferredColorScheme(.dark)
    }
}

struct GoalsView: View {
    let profile: UserProfile
    @Environment(\.trackingDate) private var currentDate
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query(sort: \ExerciseEntry.date) private var exercises: [ExerciseEntry]
    @Query(sort: \MonthlyGoal.updatedAt, order: .reverse) private var monthlyGoals: [MonthlyGoal]
    @State private var selectedPeriod: AnalyticsPeriod = .thirtyDays
    @State private var isEditingMonthlyGoal = false

    private var monthlyGoal: MonthlyGoal? {
        monthlyGoals.first { Calendar.current.isDate($0.month, equalTo: currentDate, toGranularity: .month) }
    }

    var body: some View {
        VitalityScreen(title: "Goals") {
            VStack(alignment: .leading, spacing: 14) {
                VitalitySectionLabel(text: "Monthly training goal")
                MonthlyGoalCard(goal: monthlyGoal, exercises: exercises, date: currentDate) {
                    isEditingMonthlyGoal = true
                }
                VitalitySectionLabel(text: "Weight recording goal")
                    .padding(.top, 8)
                AnalyticsPeriodPicker(selection: $selectedPeriod)
                WeightRecordingGoalView(
                    profileID: profile.id, period: selectedPeriod,
                    count: weights.filter { DateHelpers.isWithin($0.date, period: selectedPeriod, endingAt: currentDate) }.count
                )
                Text("Recording goals follow the selected rolling period. Progress appears on the Weight tab.")
                    .font(.footnote).foregroundStyle(VitalityTheme.textMuted)
            }
        }
        .sheet(isPresented: $isEditingMonthlyGoal) {
            MonthlyGoalEditorView(goal: monthlyGoal, month: currentDate)
                .preferredColorScheme(.dark)
        }
    }
}
