import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var sex: BiologicalSex
    var dateOfBirth: Date
    var heightCm: Double
    var weightKg: Double
    var bodyFatPercentage: Double?
    var leanBodyMassKg: Double?
    var activityLevel: ActivityLevel
    var fitnessGoal: FitnessGoal
    var usesMetricUnits: Bool
    var isPregnantOrBreastfeeding: Bool
    var hasMetabolismCondition: Bool
    var medicationAffectsWeight: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sex: BiologicalSex,
        dateOfBirth: Date,
        heightCm: Double,
        weightKg: Double,
        bodyFatPercentage: Double? = nil,
        leanBodyMassKg: Double? = nil,
        activityLevel: ActivityLevel,
        fitnessGoal: FitnessGoal,
        usesMetricUnits: Bool = true,
        isPregnantOrBreastfeeding: Bool = false,
        hasMetabolismCondition: Bool = false,
        medicationAffectsWeight: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sex = sex
        self.dateOfBirth = dateOfBirth
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.leanBodyMassKg = leanBodyMassKg
        self.activityLevel = activityLevel
        self.fitnessGoal = fitnessGoal
        self.usesMetricUnits = usesMetricUnits
        self.isPregnantOrBreastfeeding = isPregnantOrBreastfeeding
        self.hasMetabolismCondition = hasMetabolismCondition
        self.medicationAffectsWeight = medicationAffectsWeight
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var needsHealthDisclaimer: Bool {
        isPregnantOrBreastfeeding || hasMetabolismCondition || medicationAffectsWeight
    }
}

struct ProfileDraft {
    var sex: BiologicalSex
    var dateOfBirth: Date
    var heightCm: Double
    var weightKg: Double
    var bodyFatPercentage: Double?
    var leanBodyMassKg: Double?
    var activityLevel: ActivityLevel
    var fitnessGoal: FitnessGoal
    var usesMetricUnits: Bool
    var isPregnantOrBreastfeeding: Bool
    var hasMetabolismCondition: Bool
    var medicationAffectsWeight: Bool

    init(profile: UserProfile) {
        sex = profile.sex
        dateOfBirth = profile.dateOfBirth
        heightCm = profile.heightCm
        weightKg = profile.weightKg
        bodyFatPercentage = profile.bodyFatPercentage
        leanBodyMassKg = profile.leanBodyMassKg
        activityLevel = profile.activityLevel
        fitnessGoal = profile.fitnessGoal
        usesMetricUnits = profile.usesMetricUnits
        isPregnantOrBreastfeeding = profile.isPregnantOrBreastfeeding
        hasMetabolismCondition = profile.hasMetabolismCondition
        medicationAffectsWeight = profile.medicationAffectsWeight
    }

    var needsHealthDisclaimer: Bool {
        isPregnantOrBreastfeeding || hasMetabolismCondition || medicationAffectsWeight
    }

    func apply(to profile: UserProfile) {
        profile.sex = sex
        profile.dateOfBirth = dateOfBirth
        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.bodyFatPercentage = bodyFatPercentage
        profile.leanBodyMassKg = leanBodyMassKg
        profile.activityLevel = activityLevel
        profile.fitnessGoal = fitnessGoal
        profile.usesMetricUnits = usesMetricUnits
        profile.isPregnantOrBreastfeeding = isPregnantOrBreastfeeding
        profile.hasMetabolismCondition = hasMetabolismCondition
        profile.medicationAffectsWeight = medicationAffectsWeight
    }
}

@Model
final class ExerciseEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var exerciseType: ExerciseType
    var durationMinutes: Int
    var intensity: ExerciseIntensity
    var caloriesBurned: Double
    var notes: String
    var categoryRawValue: String = ""
    var healthWorkoutUUID: String? = nil
    var healthSourceName: String = ""
    var healthActivityName: String = ""
    var healthEnergyUnavailable: Bool = false
    var hasPerceivedEffort: Bool = true

    var displayName: String {
        healthActivityName.isEmpty ? exerciseType.displayName : healthActivityName.localized
    }

    var trainingCategory: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRawValue) ?? exerciseType.category }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        exerciseType: ExerciseType,
        durationMinutes: Int,
        intensity: ExerciseIntensity,
        caloriesBurned: Double,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.exerciseType = exerciseType
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.caloriesBurned = caloriesBurned
        self.notes = notes
    }
}

@Model
final class CalorieIntakeEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var calories: Double
    var notes: String
    // Existing records remain daily totals when this field is added to their store.
    var mealCategoryRawValue: String = "dailyTotal"

    var mealCategory: MealCategory {
        get { MealCategory(rawValue: mealCategoryRawValue) ?? .dailyTotal }
        set { mealCategoryRawValue = newValue.rawValue }
    }

    init(id: UUID = UUID(), date: Date = Date(), calories: Double, notes: String = "", mealCategory: MealCategory = .dailyTotal) {
        self.id = id
        self.date = date
        self.calories = calories
        self.notes = notes
        self.mealCategoryRawValue = mealCategory.rawValue
    }
}

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKg: Double

    init(id: UUID = UUID(), date: Date = Date(), weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}

@Model
final class DailyLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var calorieIntake: Double
    var exerciseCalories: Double
    var bmr: Double
    var tdee: Double
    var dailyBalance: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        calorieIntake: Double = 0,
        exerciseCalories: Double = 0,
        bmr: Double = 0,
        tdee: Double = 0,
        dailyBalance: Double = 0
    ) {
        self.id = id
        self.date = date
        self.calorieIntake = calorieIntake
        self.exerciseCalories = exerciseCalories
        self.bmr = bmr
        self.tdee = tdee
        self.dailyBalance = dailyBalance
    }
}

@Model
final class MonthlyGoal {
    @Attribute(.unique) var id: UUID
    var month: Date
    var type: MonthlyGoalType
    var targetValue: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        month: Date,
        type: MonthlyGoalType,
        targetValue: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.month = month
        self.type = type
        self.targetValue = targetValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct BMRResult: Equatable {
    let value: Double
    let mode: BMRCalculationMode
    let leanBodyMassKg: Double?
}

struct EnergyBalanceResult: Equatable {
    let bmr: Double
    let tdee: Double
    let calorieIntake: Double
    let exerciseCalories: Double
    let dailyBalance: Double
    let status: BalanceStatus
}

struct WeeklySummaryResult: Equatable {
    let weeklyBalance: Double
    let estimatedWeightChangeKg: Double
    let dailyResults: [EnergyBalanceResult]
}

struct MonthlyGoalProgress: Equatable {
    let currentValue: Int
    let targetValue: Int
    let elapsedFraction: Double
    let daysRemaining: Int
    let requiredDailyPace: Double

    var fractionComplete: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1)
    }

    var isComplete: Bool { currentValue >= targetValue }

    var isOnPace: Bool {
        isComplete || fractionComplete + 0.001 >= elapsedFraction
    }
}

struct CalorieTrendPoint: Identifiable, Equatable {
    let date: Date
    let calorieIntake: Double
    let calorieOutput: Double
    let dailyBalance: Double

    var id: Date { date }
}

struct WeightTrendPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
}
