import Foundation

enum HealthCalculationService {
    static let maintenanceThreshold: Double = 100

    static func calculateAge(from dateOfBirth: Date, on date: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfBirthDate = calendar.startOfDay(for: dateOfBirth)
        let startOfDate = calendar.startOfDay(for: date)
        return calendar.dateComponents([.year], from: startOfBirthDate, to: startOfDate).year ?? 0
    }

    static func calculateLeanBodyMass(weightKg: Double, bodyFatPercentage: Double) -> Double {
        weightKg * (1 - bodyFatPercentage / 100)
    }

    static func calculateBMR(profile: UserProfile, on date: Date = Date(), calendar: Calendar = .current) -> BMRResult {
        if let leanBodyMassKg = profile.leanBodyMassKg {
            return BMRResult(value: 370 + 21.6 * leanBodyMassKg, mode: .leanBodyMass, leanBodyMassKg: leanBodyMassKg)
        }

        if let bodyFatPercentage = profile.bodyFatPercentage {
            let leanBodyMass = calculateLeanBodyMass(weightKg: profile.weightKg, bodyFatPercentage: bodyFatPercentage)
            return BMRResult(value: 370 + 21.6 * leanBodyMass, mode: .bodyFatPercentage, leanBodyMassKg: leanBodyMass)
        }

        let age = Double(calculateAge(from: profile.dateOfBirth, on: date, calendar: calendar))
        let base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * age
        let value: Double
        switch profile.sex {
        case .male:
            value = base + 5
        case .female:
            value = base - 161
        }
        return BMRResult(value: value, mode: .mifflinStJeor, leanBodyMassKg: nil)
    }

    static func calculateTDEE(bmr: Double, activityFactor: Double, exerciseCalories: Double) -> Double {
        bmr * activityFactor + exerciseCalories
    }

    static func calculateDailyBalance(calorieIntake: Double, tdee: Double) -> Double {
        calorieIntake - tdee
    }

    static func calculateWeeklyBalance(_ dailyBalances: [Double]) -> Double {
        dailyBalances.reduce(0, +)
    }

    static func estimateWeeklyWeightChangeKg(weeklyBalance: Double) -> Double {
        weeklyBalance / 7700
    }

    static func balanceStatus(for dailyBalance: Double) -> BalanceStatus {
        if abs(dailyBalance) <= maintenanceThreshold {
            return .maintenance
        }
        return dailyBalance > 0 ? .surplus : .deficit
    }

    static func calculateEnergyBalance(profile: UserProfile, calorieIntake: Double, exerciseCalories: Double, on date: Date = Date()) -> EnergyBalanceResult {
        let bmrResult = calculateBMR(profile: profile, on: date)
        let tdee = calculateTDEE(
            bmr: bmrResult.value,
            activityFactor: profile.activityLevel.factor,
            exerciseCalories: exerciseCalories
        )
        let balance = calculateDailyBalance(calorieIntake: calorieIntake, tdee: tdee)
        return EnergyBalanceResult(
            bmr: bmrResult.value,
            tdee: tdee,
            calorieIntake: calorieIntake,
            exerciseCalories: exerciseCalories,
            dailyBalance: balance,
            status: balanceStatus(for: balance)
        )
    }
}
