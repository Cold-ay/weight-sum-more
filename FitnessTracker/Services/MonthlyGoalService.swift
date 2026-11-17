import Foundation

enum MonthlyGoalService {
    static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    static func progress(
        for goal: MonthlyGoal,
        exercises: [ExerciseEntry],
        asOf date: Date,
        calendar: Calendar = .current
    ) -> MonthlyGoalProgress {
        let interval = monthInterval(containing: goal.month, calendar: calendar)
        let relevantExercises = exercises.filter { interval.contains($0.date) }
        let currentValue: Int

        switch goal.type {
        case .workouts:
            currentValue = relevantExercises.count
        case .activeMinutes:
            currentValue = relevantExercises.reduce(0) { $0 + $1.durationMinutes }
        }

        let totalDays = max(calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1, 1)
        let elapsedDays: Int
        if date < interval.start {
            elapsedDays = 0
        } else if date >= interval.end {
            elapsedDays = totalDays
        } else {
            elapsedDays = min(
                (calendar.dateComponents([.day], from: interval.start, to: date).day ?? 0) + 1,
                totalDays
            )
        }
        let daysRemaining = max(totalDays - elapsedDays, 0)
        let remainingValue = max(goal.targetValue - currentValue, 0)
        let paceDays = max(daysRemaining, 1)

        return MonthlyGoalProgress(
            currentValue: currentValue,
            targetValue: goal.targetValue,
            elapsedFraction: Double(elapsedDays) / Double(totalDays),
            daysRemaining: daysRemaining,
            requiredDailyPace: Double(remainingValue) / Double(paceDays)
        )
    }
}
