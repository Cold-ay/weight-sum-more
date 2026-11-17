import Foundation

struct WeeklySummaryViewModel {
    let profile: UserProfile
    let exercises: [ExerciseEntry]
    let intakes: [CalorieIntakeEntry]
    let dailyLogs: [DailyLog]
    let endingAt: Date

    init(
        profile: UserProfile,
        exercises: [ExerciseEntry],
        intakes: [CalorieIntakeEntry],
        dailyLogs: [DailyLog] = [],
        endingAt: Date
    ) {
        self.profile = profile
        self.exercises = exercises
        self.intakes = intakes
        self.dailyLogs = dailyLogs
        self.endingAt = endingAt
    }

    var result: WeeklySummaryResult {
        let dailyResults = days.map { dailyResult(for: $0) }
        let weeklyBalance = HealthCalculationService.calculateWeeklyBalance(dailyResults.map(\.dailyBalance))
        return WeeklySummaryResult(
            weeklyBalance: weeklyBalance,
            estimatedWeightChangeKg: HealthCalculationService.estimateWeeklyWeightChangeKg(weeklyBalance: weeklyBalance),
            dailyResults: dailyResults
        )
    }

    var days: [Date] {
        DateHelpers.lastSevenDays(endingAt: endingAt)
    }

    private func dailyResult(for day: Date) -> EnergyBalanceResult {
        if let log = dailyLogs.first(where: { DateHelpers.isSameDay($0.date, day) }) {
            return EnergyBalanceResult(
                bmr: log.bmr,
                tdee: log.tdee,
                calorieIntake: log.calorieIntake,
                exerciseCalories: log.exerciseCalories,
                dailyBalance: log.dailyBalance,
                status: HealthCalculationService.balanceStatus(for: log.dailyBalance)
            )
        }

        let exerciseCalories = exercises
            .filter { DateHelpers.isSameDay($0.date, day) }
            .reduce(0) { $0 + $1.caloriesBurned }
        let calorieIntake = intakes
            .filter { DateHelpers.isSameDay($0.date, day) }
            .reduce(0) { $0 + $1.calories }
        return HealthCalculationService.calculateEnergyBalance(
            profile: profile,
            calorieIntake: calorieIntake,
            exerciseCalories: exerciseCalories,
            on: day
        )
    }
}
