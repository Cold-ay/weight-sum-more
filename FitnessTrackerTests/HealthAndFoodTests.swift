import XCTest
import SwiftData
import HealthKit
@testable import FitnessTracker

@MainActor
final class HealthAndFoodTests: XCTestCase {
    func testAppUsesWeightSumMoreBrandWithoutChangingTheDataIdentity() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "WeightSumMore")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.example.FitnessTracker")
        XCTAssertEqual(Bundle.main.executableURL?.lastPathComponent, "WeightSumMore")
    }

    func testFoodPortionsAndLabelEnergyScaleToWhatWasEaten() throws {
        XCTAssertEqual(try FoodCalorieService.estimate(energy: 242, referenceAmount: 186, consumedAmount: 93), 121, accuracy: 0.001)
        XCTAssertEqual(try FoodCalorieService.estimate(energy: 242, referenceAmount: 1, consumedAmount: 1.5), 363, accuracy: 0.001)
        XCTAssertEqual(try FoodCalorieService.estimate(energy: 250, referenceAmount: 100, consumedAmount: 60), 150, accuracy: 0.001)
        XCTAssertEqual(try FoodCalorieService.estimate(energy: 418.4, referenceAmount: 100, consumedAmount: 50, unit: .kJ), 50, accuracy: 0.001)
        XCTAssertEqual(try FoodCalorieService.estimate(energy: 0, referenceAmount: 1, consumedAmount: 2), 0)
    }

    func testInvalidFoodAmountsDoNotProduceEstimates() {
        XCTAssertThrowsError(try FoodCalorieService.estimate(energy: .nan, referenceAmount: 100, consumedAmount: 100))
        XCTAssertThrowsError(try FoodCalorieService.estimate(energy: 100, referenceAmount: 0, consumedAmount: 100))
        XCTAssertThrowsError(try FoodCalorieService.estimate(energy: 100, referenceAmount: 100, consumedAmount: -1))
        XCTAssertThrowsError(try FoodCalorieService.estimate(energy: 100, referenceAmount: 1, consumedAmount: 201))
    }

    func testCurrentStreakDeduplicatesDaysAndAllowsTodayToBeUnlogged() {
        let entries = [1, 1, 2, 3, 6].map { ExerciseEntry(date: date($0), exerciseType: .walking, durationMinutes: 20, intensity: .low, caloriesBurned: 50) }
        XCTAssertEqual(ExerciseInsights(entries: entries).currentStreak(endingAt: date(3)), 3)
        XCTAssertEqual(ExerciseInsights(entries: entries).currentStreak(endingAt: date(4)), 3)
        XCTAssertEqual(ExerciseInsights(entries: entries).currentStreak(endingAt: date(5)), 0)
    }

    func testCurrentStreakUsesCalendarDaysAcrossDaylightSaving() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dates = [DateComponents(year: 2026, month: 10, day: 31, hour: 12),
                     DateComponents(year: 2026, month: 11, day: 1, hour: 12),
                     DateComponents(year: 2026, month: 11, day: 2, hour: 12)].map { calendar.date(from: $0)! }
        let entries = dates.map { ExerciseEntry(date: $0, exerciseType: .running, durationMinutes: 30, intensity: .moderate, caloriesBurned: 200) }
        XCTAssertEqual(ExerciseInsights(entries: entries).currentStreak(endingAt: dates[2], calendar: calendar), 3)
    }

    func testHealthImportDeduplicatesIDsAndUpdatesCalorieTotals() throws {
        let container = try container()
        let profile = profile()
        container.mainContext.insert(profile)
        try container.mainContext.save()
        let record = record()
        let first = try WorkoutImportService.importRecords([record, record], profile: profile, in: container.mainContext)
        XCTAssertEqual(first.imported, 1)
        XCTAssertEqual(first.skipped, 1)
        let second = try WorkoutImportService.importRecords([record], profile: profile, in: container.mainContext)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<ExerciseEntry>()).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<DailyLog>()).first?.exerciseCalories, 200)
    }

    func testPossibleManualDuplicateNeedsExplicitReview() throws {
        let container = try container()
        let profile = profile()
        container.mainContext.insert(profile)
        container.mainContext.insert(ExerciseEntry(date: date(1), exerciseType: .running, durationMinutes: 30, intensity: .high, caloriesBurned: 200))
        try container.mainContext.save()
        let record = record()
        XCTAssertEqual(try WorkoutImportService.importRecords([record], profile: profile, in: container.mainContext).imported, 0)
        XCTAssertEqual(try WorkoutImportService.importRecords([record], allowPossibleDuplicates: [record.id], profile: profile, in: container.mainContext).imported, 1)
    }

    func testHealthImportRefreshesAnAlreadyLoadedDailyLog() throws {
        let container = try container()
        let profile = profile()
        container.mainContext.insert(profile)
        let log = try FitnessDataService.upsertDailyLog(for: date(1), profile: profile, in: container.mainContext)
        XCTAssertEqual(log.exerciseCalories, 0)
        _ = try WorkoutImportService.importRecords([record()], profile: profile, in: container.mainContext)
        let refreshed = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<DailyLog>()).first)
        XCTAssertEqual(refreshed.exerciseCalories, 200)
    }

    func testMissingHealthEnergyAndEffortAreNotInvented() throws {
        let container = try container()
        let profile = profile()
        container.mainContext.insert(profile)
        try container.mainContext.save()
        let record = record(energy: nil)
        _ = try WorkoutImportService.importRecords([record], profile: profile, in: container.mainContext)
        let entry = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<ExerciseEntry>()).first)
        XCTAssertTrue(entry.healthEnergyUnavailable)
        XCTAssertFalse(entry.hasPerceivedEffort)
        XCTAssertEqual(entry.caloriesBurned, 0)
        XCTAssertEqual(entry.healthWorkoutUUID, record.id.uuidString)
    }

    func testInvalidBatchCannotPartiallyImport() throws {
        let container = try container()
        let profile = profile()
        container.mainContext.insert(profile)
        try container.mainContext.save()
        let invalid = HealthWorkoutRecord(id: UUID(), startDate: date(2), endDate: date(2), durationSeconds: .nan,
                                         energyKcal: 200, exerciseType: .running, suggestedCategory: .cardio, activityName: "Running", sourceName: "Test")
        XCTAssertThrowsError(try WorkoutImportService.importRecords([record(), invalid], profile: profile, in: container.mainContext))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<ExerciseEntry>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<DailyLog>()).isEmpty)
    }

    func testUnknownHealthActivityRequiresCategoryAndKnownStrengthMapsCorrectly() throws {
        XCTAssertEqual(HealthWorkoutService.mapping(.functionalStrengthTraining).1, .strength)
        XCTAssertEqual(HealthWorkoutService.mapping(.yoga).1, .mindAndBody)
        XCTAssertNil(HealthWorkoutService.mapping(.other).1)
        let container = try container()
        let profile = profile()
        container.mainContext.insert(profile)
        try container.mainContext.save()
        let record = HealthWorkoutRecord(id: UUID(), startDate: date(1), endDate: date(1).addingTimeInterval(1_800),
                                         durationSeconds: 1_800, energyKcal: 100, exerciseType: .other,
                                         suggestedCategory: nil, activityName: "Health workout", sourceName: "Test")
        XCTAssertThrowsError(try WorkoutImportService.importRecords([record], profile: profile, in: container.mainContext))
        XCTAssertEqual(try WorkoutImportService.importRecords([record], categories: [record.id: .mindAndBody], profile: profile, in: container.mainContext).imported, 1)
    }

    func testHealthReadPurposeIsBundledInBothLanguages() throws {
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription"))
        let path = try XCTUnwrap(Bundle.main.path(forResource: "zh-Hant", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertTrue(bundle.localizedString(forKey: "NSHealthShareUsageDescription", value: nil, table: "InfoPlist").contains("健康"))
    }

    private func date(_ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12))!
    }
    private func record(energy: Double? = 200) -> HealthWorkoutRecord {
        HealthWorkoutRecord(id: UUID(), startDate: date(1), endDate: date(1).addingTimeInterval(1_800),
                            durationSeconds: 1_800, energyKcal: energy, exerciseType: .running,
                            suggestedCategory: .cardio, activityName: "Running", sourceName: "Apple Watch")
    }
    private func profile() -> UserProfile {
        UserProfile(sex: .male, dateOfBirth: date(1).addingTimeInterval(-30 * 365 * 86_400), heightCm: 175,
                    weightKg: 75, activityLevel: .lightlyActive, fitnessGoal: .maintainWeight)
    }
    private func container() throws -> ModelContainer {
        let schema = Schema([UserProfile.self, DailyLog.self, ExerciseEntry.self, CalorieIntakeEntry.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
