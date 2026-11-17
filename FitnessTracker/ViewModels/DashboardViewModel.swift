import Foundation

struct DashboardViewModel {
    let profile: UserProfile
    let exercises: [ExerciseEntry]
    let intakes: [CalorieIntakeEntry]
    let dailyLogs: [DailyLog]
    let date: Date

    init(
        profile: UserProfile,
        exercises: [ExerciseEntry],
        intakes: [CalorieIntakeEntry],
        dailyLogs: [DailyLog] = [],
        date: Date
    ) {
        self.profile = profile
        self.exercises = exercises
        self.intakes = intakes
        self.dailyLogs = dailyLogs
        self.date = date
    }

    var todayExerciseCalories: Double {
        exercises
            .filter { DateHelpers.isSameDay($0.date, date) }
            .reduce(0) { $0 + $1.caloriesBurned }
    }

    var todayCalorieIntake: Double {
        IntakeAggregation.total(intakes.filter { DateHelpers.isSameDay($0.date, date) })
    }

    var bmrResult: BMRResult {
        HealthCalculationService.calculateBMR(profile: profile, on: date)
    }

    var energyBalance: EnergyBalanceResult {
        if let log = dailyLogs.first(where: { DateHelpers.isSameDay($0.date, date) }) {
            return EnergyBalanceResult(
                bmr: log.bmr,
                tdee: log.tdee,
                calorieIntake: log.calorieIntake,
                exerciseCalories: log.exerciseCalories,
                dailyBalance: log.dailyBalance,
                status: HealthCalculationService.balanceStatus(for: log.dailyBalance)
            )
        }

        return HealthCalculationService.calculateEnergyBalance(
            profile: profile,
            calorieIntake: todayCalorieIntake,
            exerciseCalories: todayExerciseCalories,
            on: date
        )
    }

    var characterActivity: ExerciseType? {
        exercises.filter { DateHelpers.isSameDay($0.date, date) && $0.date <= date }
            .max { $0.date < $1.date }?.exerciseType
    }

    func characterProgress(monthlyGoal: MonthlyGoal?) -> CharacterProgress {
        let calendar = Calendar.current
        let consistencyScore: Double

        if let monthlyGoal {
            let progress = MonthlyGoalService.progress(for: monthlyGoal, exercises: exercises, asOf: date)
            consistencyScore = progress.elapsedFraction > 0
                ? min(progress.fractionComplete / progress.elapsedFraction, 1)
                : 0.35
        } else {
            let intervalStart = calendar.date(byAdding: .day, value: -6, to: date) ?? date
            let activeDays = Set(exercises.filter { $0.date >= intervalStart && $0.date <= date }.map {
                calendar.startOfDay(for: $0.date)
            }).count
            consistencyScore = min(Double(activeDays) / 4, 1)
        }

        let activityScore = min(todayExerciseCalories / 350, 1)
        let hasNutritionData = intakes.contains { DateHelpers.isSameDay($0.date, date) }
        let nutritionScore = hasNutritionData ? goalAlignmentScore(for: energyBalance.dailyBalance) : 0.5
        let score = (consistencyScore * 0.65) + (activityScore * 0.25) + (nutritionScore * 0.10)

        let higherBodyFat = profile.bodyFatPercentage.map { bodyFat in
            bodyFat >= (profile.sex == .male ? 28 : 36)
        } ?? false

        let build: CharacterBuild
        if higherBodyFat && score < 0.55 {
            build = .soft
        } else if score >= 0.82 {
            build = .powerful
        } else if score >= 0.60 {
            build = .athletic
        } else if score >= 0.34 {
            build = .balanced
        } else {
            build = .lean
        }

        return CharacterProgress(score: score, build: build)
    }

    private func goalAlignmentScore(for balance: Double) -> Double {
        switch profile.fitnessGoal {
        case .loseWeight:
            if balance >= -700 && balance <= -150 { return 1 }
            return balance < -1_000 || balance > 400 ? 0.15 : 0.55
        case .maintainWeight:
            if abs(balance) <= 250 { return 1 }
            return abs(balance) >= 800 ? 0.15 : 0.55
        case .gainWeight:
            if balance >= 150 && balance <= 550 { return 1 }
            return balance < -500 || balance > 1_000 ? 0.15 : 0.55
        case .gainMuscle:
            if todayExerciseCalories > 0 && balance >= -100 && balance <= 550 { return 1 }
            return balance < -600 || balance > 1_000 ? 0.15 : 0.55
        }
    }

    func motivationMessage(monthlyGoal: MonthlyGoal?) -> String {
        guard let monthlyGoal else { return motivationMessage }
        let progress = MonthlyGoalService.progress(for: monthlyGoal, exercises: exercises, asOf: date)
        let tally = L10n.format("%ld of %ld %@", progress.currentValue, progress.targetValue, monthlyGoal.type.unitName)
        if progress.isComplete {
            return L10n.format("%@. Target met. Look at you, actually delivering what you ordered. Enjoy the win; recovery is on the menu too.", tally)
        }
        if !progress.isOnPace {
            return L10n.format("%@. You ordered results, but your target is still waiting for service. Book your next manageable session. The calendar does not accept excuses as payment.", tally)
        }
        return L10n.format("%@. On pace. Finally, an order with some follow-through. Keep your next planned session; no need to double the order.", tally)
    }

    var motivationMessage: String {
        switch profile.fitnessGoal {
        case .gainMuscle:
            if todayExerciseCalories > 0 {
                return "Workout logged. So you do know where the gym is. Good. Eat, recover, and come back for your next planned session.".localized
            }
            return "Muscles ordered. Delivery instructions missing. Plan your next strength session and show up for it. If today is a rest day, recover like you mean it.".localized
        case .gainWeight:
            return "You ordered weight gain. Wishing is not a side dish. Keep up with your planned meals, log honestly, and give the routine time to work.".localized
        case .loseWeight:
            return "You ordered progress, not a fresh start every Monday. Follow your plan today, log honestly, and stop expecting express delivery. Meals and rest stay on the menu.".localized
        case .maintainWeight:
            return "Maintenance. The usual order. Keep the habits that work, and stop turning one odd day into a five-season drama. Consistency, please.".localized
        }
    }
}

enum CharacterBuild: Int, CaseIterable {
    case lean
    case balanced
    case soft
    case athletic
    case powerful

    var title: String {
        switch self {
        case .lean: "Fresh Start".localized
        case .balanced: "Finding Rhythm".localized
        case .soft: "Building Momentum".localized
        case .athletic: "Feeling Fit".localized
        case .powerful: "Power Mode".localized
        }
    }

    var encouragement: String {
        switch self {
        case .lean: "Every rep adds a little spark. Let’s get moving!".localized
        case .balanced: "Nice rhythm—your training buddy is taking shape.".localized
        case .soft: "Progress has many shapes. Keep stacking healthy days.".localized
        case .athletic: "Consistency looks good on you. Keep the streak alive!".localized
        case .powerful: "Your hard work is showing. You’re in power mode!".localized
        }
    }
}

struct CharacterProgress {
    let score: Double
    let build: CharacterBuild

    var percentage: Int { Int((min(max(score, 0), 1) * 100).rounded()) }
}
