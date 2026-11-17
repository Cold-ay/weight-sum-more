import Foundation

enum HealthValidationError: LocalizedError, Equatable {
    case invalidDateOfBirth
    case invalidHeight
    case invalidWeight
    case invalidBodyFat
    case invalidLeanBodyMass
    case invalidExerciseDuration
    case invalidExerciseCalories
    case invalidCalorieIntake

    var errorDescription: String? {
        switch self {
        case .invalidDateOfBirth:
            "Enter a date of birth in the past.".localized
        case .invalidHeight:
            "Height must be between 50 and 300 cm.".localized
        case .invalidWeight:
            "Weight must be between 20 and 500 kg.".localized
        case .invalidBodyFat:
            "Body fat must be between 1% and 70%.".localized
        case .invalidLeanBodyMass:
            "Lean body mass must be greater than zero and less than or equal to body weight.".localized
        case .invalidExerciseDuration:
            "Exercise duration must be between 1 and 1,440 minutes.".localized
        case .invalidExerciseCalories:
            "Exercise calories must be between 0 and 20,000 kcal.".localized
        case .invalidCalorieIntake:
            "Calorie intake must be between 0 and 20,000 kcal.".localized
        }
    }
}

enum HealthValidationService {
    static func optionalMeasurement(_ text: String, invalidValue: HealthValidationError) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value.isFinite else { throw invalidValue }
        return value
    }

    static func validateProfile(
        dateOfBirth: Date,
        heightCm: Double,
        weightKg: Double,
        bodyFatPercentage: Double?,
        leanBodyMassKg: Double?,
        now: Date = Date()
    ) throws {
        guard dateOfBirth < now else { throw HealthValidationError.invalidDateOfBirth }
        guard (50...300).contains(heightCm) else { throw HealthValidationError.invalidHeight }
        guard (20...500).contains(weightKg) else { throw HealthValidationError.invalidWeight }

        if let bodyFatPercentage {
            guard (1...70).contains(bodyFatPercentage) else { throw HealthValidationError.invalidBodyFat }
        }

        if let leanBodyMassKg {
            guard leanBodyMassKg > 0, leanBodyMassKg <= weightKg else {
                throw HealthValidationError.invalidLeanBodyMass
            }
        }
    }

    static func validateExercise(durationMinutes: Int, caloriesBurned: Double) throws {
        guard (1...1_440).contains(durationMinutes) else {
            throw HealthValidationError.invalidExerciseDuration
        }
        guard (0...20_000).contains(caloriesBurned) else {
            throw HealthValidationError.invalidExerciseCalories
        }
    }

    static func validateCalorieIntake(_ calories: Double) throws {
        guard (0...20_000).contains(calories) else {
            throw HealthValidationError.invalidCalorieIntake
        }
    }

    static func validateWeight(_ weightKg: Double) throws {
        guard (20...500).contains(weightKg) else {
            throw HealthValidationError.invalidWeight
        }
    }
}
