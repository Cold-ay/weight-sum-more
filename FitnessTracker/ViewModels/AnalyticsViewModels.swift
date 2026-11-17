import Foundation

struct CalorieAnalyticsViewModel {
    let profile: UserProfile
    let exercises: [ExerciseEntry]
    let intakes: [CalorieIntakeEntry]
    let dailyLogs: [DailyLog]
    let period: AnalyticsPeriod
    let endingAt: Date

    var days: [Date] {
        if period == .allTime {
            guard let earliestDate = (exercises.map(\.date) + intakes.map(\.date) + dailyLogs.map(\.date)).min() else {
                return []
            }
            return DateHelpers.dates(from: earliestDate, through: endingAt)
        }
        return DateHelpers.dates(in: period, endingAt: endingAt)
    }

    var points: [CalorieTrendPoint] {
        days.compactMap { day in
            // A missing food log is unknown intake, not an intentional zero.
            let hasIntake = intakes.contains { DateHelpers.isSameDay($0.date, day) }
                || dailyLogs.contains { DateHelpers.isSameDay($0.date, day) && $0.calorieIntake > 0 }
            guard hasIntake else { return nil }
            let result = energyBalance(for: day)
            return CalorieTrendPoint(
                date: day,
                calorieIntake: result.calorieIntake,
                calorieOutput: result.tdee,
                dailyBalance: result.dailyBalance
            )
        }
    }

    var totalIntake: Double {
        points.reduce(0) { $0 + $1.calorieIntake }
    }

    var totalOutput: Double {
        points.reduce(0) { $0 + $1.calorieOutput }
    }

    var totalBalance: Double {
        points.reduce(0) { $0 + $1.dailyBalance }
    }

    var estimatedWeightChangeKg: Double {
        HealthCalculationService.estimateWeeklyWeightChangeKg(weeklyBalance: totalBalance)
    }

    private func energyBalance(for day: Date) -> EnergyBalanceResult {
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
        let calorieIntake = IntakeAggregation.total(intakes.filter { DateHelpers.isSameDay($0.date, day) })
        return HealthCalculationService.calculateEnergyBalance(
            profile: profile,
            calorieIntake: calorieIntake,
            exerciseCalories: exerciseCalories,
            on: day
        )
    }
}

struct WeightAnalyticsViewModel {
    let weights: [WeightEntry]
    let usesMetricUnits: Bool
    let period: AnalyticsPeriod
    let endingAt: Date

    var entries: [WeightEntry] {
        weights
            .filter { DateHelpers.isWithin($0.date, period: period, endingAt: endingAt) }
            .sorted { $0.date < $1.date }
    }

    var points: [WeightTrendPoint] {
        entries.map {
            WeightTrendPoint(
                id: $0.id,
                date: $0.date,
                weight: usesMetricUnits ? $0.weightKg : UnitConversionService.convertKgToLb($0.weightKg)
            )
        }
    }

    var weightChangeKg: Double? {
        guard let first = entries.first, let last = entries.last, first.id != last.id else {
            return nil
        }
        return last.weightKg - first.weightKg
    }

    var displayWeightChange: Double? {
        weightChangeKg.map { usesMetricUnits ? $0 : UnitConversionService.convertKgToLb($0) }
    }

    var unit: String {
        usesMetricUnits ? "kg" : "lb"
    }
}
