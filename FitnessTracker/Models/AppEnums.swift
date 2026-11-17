import Foundation
import SwiftUI

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: "Male".localized
        case .female: "Female".localized
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: "Sedentary".localized
        case .lightlyActive: "Lightly active".localized
        case .moderatelyActive: "Moderately active".localized
        case .veryActive: "Very active".localized
        case .extraActive: "Extra active".localized
        }
    }

    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case loseWeight
    case maintainWeight
    case gainWeight
    case gainMuscle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loseWeight: "Lose weight".localized
        case .maintainWeight: "Maintain weight".localized
        case .gainWeight: "Gain weight".localized
        case .gainMuscle: "Gain muscle".localized
        }
    }

    var systemImage: String {
        switch self {
        case .loseWeight: "arrow.down.forward"
        case .maintainWeight: "equal"
        case .gainWeight: "arrow.up.forward"
        case .gainMuscle: "dumbbell"
        }
    }
}

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case running
    case walking
    case cycling
    case swimming
    case gym
    case yoga
    case bodyweight
    case pilates
    case stretching
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running: "Running".localized
        case .walking: "Walking".localized
        case .cycling: "Cycling".localized
        case .swimming: "Swimming".localized
        case .gym: "Weight training".localized
        case .yoga: "Yoga".localized
        case .bodyweight: "Bodyweight training".localized
        case .pilates: "Pilates".localized
        case .stretching: "Stretching".localized
        case .other: "Custom workout".localized
        }
    }
}

enum ExerciseCategory: String, CaseIterable, Identifiable {
    case cardio, strength, mindAndBody
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cardio: "Cardio".localized
        case .strength: "Strength".localized
        case .mindAndBody: "Mind & body".localized
        }
    }
}

extension ExerciseType {
    var category: ExerciseCategory {
        switch self {
        case .running, .walking, .cycling, .swimming: .cardio
        case .gym, .bodyweight: .strength
        case .yoga, .pilates, .stretching: .mindAndBody
        case .other: .cardio
        }
    }
    var systemImage: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .gym: "dumbbell"
        case .yoga: "figure.yoga"
        case .bodyweight: "figure.strengthtraining.functional"
        case .pilates: "figure.pilates"
        case .stretching: "figure.flexibility"
        case .other: "figure.mixed.cardio"
        }
    }
}

enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case dailyTotal, breakfast, lunch, dinner, snack
    var id: String { rawValue }
    static var entryCategories: [MealCategory] { [.breakfast, .lunch, .dinner, .snack] }
    static func suggested(at date: Date) -> MealCategory {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 11..<16: .lunch
        case 16..<21: .dinner
        default: .snack
        }
    }
    var displayName: String {
        switch self {
        case .dailyTotal: "Previous daily estimate".localized
        case .breakfast: "Breakfast".localized
        case .lunch: "Lunch".localized
        case .dinner: "Dinner".localized
        case .snack: "Snacks".localized
        }
    }
    var systemImage: String {
        switch self {
        case .dailyTotal: "calendar"
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .snack: "carrot"
        }
    }
}

enum ExerciseIntensity: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low".localized
        case .moderate: "Moderate".localized
        case .high: "High".localized
        }
    }

    var effortDescription: String {
        switch self {
        case .low: "Feels easy".localized
        case .moderate: "Feels manageable".localized
        case .high: "Feels demanding".localized
        }
    }
}

enum BalanceStatus: String, Codable {
    case deficit
    case maintenance
    case surplus

    var displayName: String {
        switch self {
        case .deficit: "Deficit".localized
        case .maintenance: "Maintenance".localized
        case .surplus: "Surplus".localized
        }
    }

    var color: Color {
        switch self {
        case .deficit: VitalityTheme.deficit
        case .maintenance: VitalityTheme.success
        case .surplus: VitalityTheme.warning
        }
    }
}

enum BMRCalculationMode: String, Codable {
    case leanBodyMass
    case bodyFatPercentage
    case mifflinStJeor

    var displayName: String {
        switch self {
        case .leanBodyMass: "Lean body mass".localized
        case .bodyFatPercentage: "Body fat estimate".localized
        case .mifflinStJeor: "Mifflin-St Jeor".localized
        }
    }
}

enum MonthlyGoalType: String, Codable, CaseIterable, Identifiable {
    case workouts
    case activeMinutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .workouts: "Workouts".localized
        case .activeMinutes: "Active minutes".localized
        }
    }

    var unitName: String {
        switch self {
        case .workouts: "workouts".localized
        case .activeMinutes: "minutes".localized
        }
    }

    var systemImage: String {
        switch self {
        case .workouts: "figure.run"
        case .activeMinutes: "timer"
        }
    }
}

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case oneDay
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear
    case allTime

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .oneDay: "1D"
        case .sevenDays: "7D"
        case .thirtyDays: "30D"
        case .ninetyDays: "90D"
        case .oneYear: "1Y"
        case .allTime: "All time".localized
        }
    }

    var displayName: String {
        switch self {
        case .oneDay: "Today".localized
        case .sevenDays: "Last 7 days".localized
        case .thirtyDays: "Last 30 days".localized
        case .ninetyDays: "Last 90 days".localized
        case .oneYear: "Last year".localized
        case .allTime: "All time".localized
        }
    }

    var dayCount: Int {
        switch self {
        case .oneDay: 1
        case .sevenDays: 7
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .oneYear: 365
        case .allTime: 0
        }
    }
}
