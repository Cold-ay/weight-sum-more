import XCTest
@testable import FitnessTracker

final class HealthCalculationServiceTests: XCTestCase {
    func testUnitConversionsUseMetricStorage() {
        XCTAssertEqual(UnitConversionService.convertLbToKg(154), 69.853, accuracy: 0.001)
        XCTAssertEqual(UnitConversionService.convertKgToLb(70), 154.324, accuracy: 0.001)
        XCTAssertEqual(UnitConversionService.convertFeetInchesToCm(feet: 5, inches: 10), 177.8, accuracy: 0.001)
    }

    func testAgeCalculationHandlesBirthdays() {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = calendar.date(from: DateComponents(year: 1990, month: 7, day: 9))!
        let dayBeforeBirthday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        let birthday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 9))!

        XCTAssertEqual(HealthCalculationService.calculateAge(from: birthDate, on: dayBeforeBirthday), 35)
        XCTAssertEqual(HealthCalculationService.calculateAge(from: birthDate, on: birthday), 36)
    }

    func testBMRUsesLeanBodyMassBeforeBodyFatOrMifflin() {
        let profile = UserProfile(
            sex: .male,
            dateOfBirth: Date(timeIntervalSince1970: 0),
            heightCm: 180,
            weightKg: 90,
            bodyFatPercentage: 40,
            leanBodyMassKg: 70,
            activityLevel: .sedentary,
            fitnessGoal: .maintainWeight
        )

        let result = HealthCalculationService.calculateBMR(profile: profile, on: Date())

        XCTAssertEqual(result.value, 1882, accuracy: 0.001)
        XCTAssertEqual(result.mode, .leanBodyMass)
    }

    func testBMRUsesBodyFatBeforeMifflinWhenLeanMassMissing() {
        let profile = UserProfile(
            sex: .female,
            dateOfBirth: Date(timeIntervalSince1970: 0),
            heightCm: 165,
            weightKg: 70,
            bodyFatPercentage: 30,
            leanBodyMassKg: nil,
            activityLevel: .moderatelyActive,
            fitnessGoal: .loseWeight
        )

        let result = HealthCalculationService.calculateBMR(profile: profile, on: Date())

        XCTAssertEqual(result.value, 1428.4, accuracy: 0.001)
        XCTAssertEqual(result.mode, .bodyFatPercentage)
    }

    func testMifflinStJeorUsesSexSpecificConstants() {
        let birthDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1996, month: 7, day: 8))!
        let referenceDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 8))!
        let male = UserProfile(sex: .male, dateOfBirth: birthDate, heightCm: 180, weightKg: 80, activityLevel: .lightlyActive, fitnessGoal: .maintainWeight)
        let female = UserProfile(sex: .female, dateOfBirth: birthDate, heightCm: 165, weightKg: 65, activityLevel: .lightlyActive, fitnessGoal: .maintainWeight)

        XCTAssertEqual(HealthCalculationService.calculateBMR(profile: male, on: referenceDate).value, 1780, accuracy: 0.001)
        XCTAssertEqual(HealthCalculationService.calculateBMR(profile: female, on: referenceDate).value, 1370.25, accuracy: 0.001)
    }

    func testEnergyBalanceAndWeeklyEstimate() {
        let tdee = HealthCalculationService.calculateTDEE(bmr: 1600, activityFactor: ActivityLevel.moderatelyActive.factor, exerciseCalories: 300)
        let dailyBalance = HealthCalculationService.calculateDailyBalance(calorieIntake: 2400, tdee: tdee)
        let weeklyBalance = HealthCalculationService.calculateWeeklyBalance([dailyBalance, -250, 100, 0, 50, -100, 200])

        XCTAssertEqual(ActivityLevel.extraActive.factor, 1.9, accuracy: 0.001)
        XCTAssertEqual(tdee, 2780, accuracy: 0.001)
        XCTAssertEqual(dailyBalance, -380, accuracy: 0.001)
        XCTAssertEqual(weeklyBalance, -380, accuracy: 0.001)
        XCTAssertEqual(HealthCalculationService.estimateWeeklyWeightChangeKg(weeklyBalance: weeklyBalance), -0.04935, accuracy: 0.0001)
        XCTAssertEqual(HealthCalculationService.balanceStatus(for: 80), .maintenance)
        XCTAssertEqual(HealthCalculationService.balanceStatus(for: 150), .surplus)
        XCTAssertEqual(HealthCalculationService.balanceStatus(for: -150), .deficit)
    }

    func testDashboardMotivationAdaptsToGoalAndProgress() {
        let previousLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        UserDefaults.standard.set("en", forKey: "appLanguage")
        defer {
            if let previousLanguage { UserDefaults.standard.set(previousLanguage, forKey: "appLanguage") }
            else { UserDefaults.standard.removeObject(forKey: "appLanguage") }
        }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = UserProfile(
            sex: .male,
            dateOfBirth: Date(timeIntervalSince1970: 0),
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            fitnessGoal: .gainMuscle
        )
        let workout = ExerciseEntry(
            date: date,
            exerciseType: .gym,
            durationMinutes: 45,
            intensity: .high,
            caloriesBurned: 350
        )

        var viewModel = DashboardViewModel(
            profile: profile,
            exercises: [workout],
            intakes: [],
            date: date
        )
        XCTAssertTrue(viewModel.motivationMessage.contains("Workout logged"))

        profile.fitnessGoal = .gainWeight
        viewModel = DashboardViewModel(profile: profile, exercises: [], intakes: [], date: date)
        XCTAssertTrue(viewModel.motivationMessage.contains("weight gain"))

        profile.fitnessGoal = .loseWeight
        XCTAssertTrue(viewModel.motivationMessage.contains("express delivery"))
    }
}
