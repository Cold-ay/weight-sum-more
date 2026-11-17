import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class FitnessDataServiceTests: XCTestCase {
    func testCalorieAndExerciseWritesMaterializeDailyLog() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let date = fixedDate(year: 2026, month: 8, day: 20)
        let profile = makeProfile()
        context.insert(profile)

        try FitnessDataService.saveCalorieIntake(
            profile: profile,
            entry: nil,
            date: date,
            calories: 2_200,
            notes: "",
            in: context
        )
        try FitnessDataService.saveExercise(
            profile: profile,
            entry: nil,
            date: date,
            exerciseType: .running,
            durationMinutes: 30,
            intensity: .high,
            caloriesBurned: 300,
            notes: "",
            in: context
        )

        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].calorieIntake, 2_200, accuracy: 0.001)
        XCTAssertEqual(logs[0].exerciseCalories, 300, accuracy: 0.001)
        XCTAssertEqual(logs[0].dailyBalance, 2_200 - logs[0].tdee, accuracy: 0.001)
    }

    func testMovingCalorieEntryRecalculatesBothDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstDate = fixedDate(year: 2026, month: 8, day: 19)
        let secondDate = fixedDate(year: 2026, month: 8, day: 20)
        let profile = makeProfile()
        context.insert(profile)

        let entry = CalorieIntakeEntry(date: firstDate, calories: 2_000)
        context.insert(entry)
        try FitnessDataService.saveCalorieIntake(
            profile: profile,
            entry: entry,
            date: firstDate,
            calories: 2_000,
            notes: "",
            in: context
        )
        try FitnessDataService.saveCalorieIntake(
            profile: profile,
            entry: entry,
            date: secondDate,
            calories: 2_200,
            notes: "",
            in: context
        )

        let logs = try context.fetch(FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\DailyLog.date)]))
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[0].calorieIntake, 0, accuracy: 0.001)
        XCTAssertEqual(logs[1].calorieIntake, 2_200, accuracy: 0.001)
    }

    func testWeightWriteUpdatesProfileToLatestWeighIn() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let profile = makeProfile()
        context.insert(profile)
        let earlier = fixedDate(year: 2026, month: 8, day: 19)
        let latest = fixedDate(year: 2026, month: 8, day: 20)

        try FitnessDataService.saveWeight(profile: profile, entry: nil, date: earlier, weightKg: 80, in: context)
        try FitnessDataService.saveWeight(profile: profile, entry: nil, date: latest, weightKg: 78.5, in: context)

        XCTAssertEqual(profile.weightKg, 78.5, accuracy: 0.001)
        let todayLog = try XCTUnwrap(context.fetch(FetchDescriptor<DailyLog>()).first {
            DateHelpers.isSameDay($0.date, Date())
        })
        XCTAssertEqual(todayLog.bmr, HealthCalculationService.calculateBMR(profile: profile).value, accuracy: 0.001)
    }

    func testNonNumericOptionalMeasurementsAreRejected() {
        XCTAssertThrowsError(try HealthValidationService.optionalMeasurement("abc", invalidValue: .invalidBodyFat))
        XCTAssertThrowsError(try HealthValidationService.optionalMeasurement("nan", invalidValue: .invalidLeanBodyMass))
        XCTAssertNil(try HealthValidationService.optionalMeasurement("  ", invalidValue: .invalidBodyFat))
    }

    func testInvalidProfileDraftCannotMutateStoredProfile() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let profile = makeProfile()
        context.insert(profile)
        try context.save()
        var draft = ProfileDraft(profile: profile)
        draft.weightKg = -10
        draft.fitnessGoal = .loseWeight

        XCTAssertThrowsError(try FitnessDataService.commitProfileChanges(profile, draft: draft, in: context))
        XCTAssertEqual(profile.weightKg, 80)
        XCTAssertEqual(profile.fitnessGoal, .maintainWeight)
        let storedProfile = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(storedProfile.weightKg, 80)
        XCTAssertEqual(storedProfile.fitnessGoal, .maintainWeight)
    }

    func testDeletingLatestWeightRestoresPreviousWeightAndRefreshesToday() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let profile = makeProfile()
        context.insert(profile)
        try FitnessDataService.saveWeight(profile: profile, entry: nil, date: fixedDate(year: 2026, month: 8, day: 19), weightKg: 80, in: context)
        try FitnessDataService.saveWeight(profile: profile, entry: nil, date: fixedDate(year: 2026, month: 8, day: 20), weightKg: 78, in: context)
        let latest = try XCTUnwrap(context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\WeightEntry.date, order: .reverse)])).first)

        try FitnessDataService.deleteWeight(latest, profile: profile, in: context)

        XCTAssertEqual(profile.weightKg, 80)
        let today = try XCTUnwrap(context.fetch(FetchDescriptor<DailyLog>()).first { DateHelpers.isSameDay($0.date, Date()) })
        XCTAssertEqual(today.bmr, HealthCalculationService.calculateBMR(profile: profile).value, accuracy: 0.001)
    }

    func testInvalidValuesAreRejectedBeforePersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let profile = makeProfile()
        context.insert(profile)

        XCTAssertThrowsError(try FitnessDataService.saveCalorieIntake(
            profile: profile,
            entry: nil,
            date: Date(),
            calories: -1,
            notes: "",
            in: context
        )) { error in
            XCTAssertEqual(error as? HealthValidationError, .invalidCalorieIntake)
        }
        XCTAssertThrowsError(try FitnessDataService.saveExercise(
            profile: profile,
            entry: nil,
            date: Date(),
            exerciseType: .walking,
            durationMinutes: 0,
            intensity: .low,
            caloriesBurned: 50,
            notes: "",
            in: context
        )) { error in
            XCTAssertEqual(error as? HealthValidationError, .invalidExerciseDuration)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            DailyLog.self,
            ExerciseEntry.self,
            WeightEntry.self,
            CalorieIntakeEntry.self
        ])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            sex: .male,
            dateOfBirth: fixedDate(year: 1990, month: 1, day: 1),
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            fitnessGoal: .maintainWeight
        )
    }

    private func fixedDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }
}
