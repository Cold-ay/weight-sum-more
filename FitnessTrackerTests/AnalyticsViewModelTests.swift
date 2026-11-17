import XCTest
@testable import FitnessTracker

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    func testCalorieAnalyticsUsesSelectedPeriodAndStoredLogs() {
        let endingAt = fixedDate(year: 2026, month: 8, day: 20)
        let profile = makeProfile()
        let logs = [
            DailyLog(date: fixedDate(year: 2026, month: 8, day: 19), calorieIntake: 2_000, exerciseCalories: 200, bmr: 1_700, tdee: 2_300, dailyBalance: -300),
            DailyLog(date: endingAt, calorieIntake: 2_400, exerciseCalories: 400, bmr: 1_700, tdee: 2_500, dailyBalance: -100)
        ]
        let viewModel = CalorieAnalyticsViewModel(
            profile: profile,
            exercises: [],
            intakes: [],
            dailyLogs: logs,
            period: .sevenDays,
            endingAt: endingAt
        )

        XCTAssertEqual(viewModel.points.count, 2)
        XCTAssertEqual(viewModel.points.last?.calorieIntake ?? 0, 2_400, accuracy: 0.001)
        XCTAssertEqual(viewModel.points.last?.dailyBalance ?? 0, -100, accuracy: 0.001)
        XCTAssertEqual(viewModel.totalIntake, 4_400, accuracy: 0.001)
        XCTAssertEqual(viewModel.totalBalance, -400, accuracy: 0.001)
    }

    func testUnloggedDaysDoNotCreateAFalseCalorieDeficit() {
        let date = fixedDate(year: 2026, month: 8, day: 20)
        let viewModel = CalorieAnalyticsViewModel(
            profile: makeProfile(), exercises: [], intakes: [],
            dailyLogs: [DailyLog(date: date, bmr: 1_700, tdee: 2_300, dailyBalance: -2_300)],
            period: .oneYear, endingAt: date
        )

        XCTAssertTrue(viewModel.points.isEmpty)
        XCTAssertEqual(viewModel.totalBalance, 0)
        XCTAssertEqual(viewModel.estimatedWeightChangeKg, 0)
    }

    func testExplicitZeroIntakeCountsAsALoggedDay() {
        let date = fixedDate(year: 2026, month: 8, day: 20)
        let viewModel = CalorieAnalyticsViewModel(
            profile: makeProfile(), exercises: [],
            intakes: [CalorieIntakeEntry(date: date, calories: 0)], dailyLogs: [],
            period: .oneDay, endingAt: date
        )

        XCTAssertEqual(viewModel.points.count, 1)
        XCTAssertLessThan(viewModel.totalBalance, 0)
    }

    func testAllTimeIncludesOldIntakeAndExcludesFutureDays() {
        let endingAt = fixedDate(year: 2026, month: 8, day: 20)
        let oldDate = fixedDate(year: 2024, month: 1, day: 1)
        let future = fixedDate(year: 2026, month: 8, day: 21)
        let viewModel = CalorieAnalyticsViewModel(
            profile: makeProfile(), exercises: [],
            intakes: [CalorieIntakeEntry(date: oldDate, calories: 2_000), CalorieIntakeEntry(date: future, calories: 3_000)],
            dailyLogs: [], period: .allTime, endingAt: endingAt
        )

        XCTAssertEqual(viewModel.points.count, 1)
        XCTAssertEqual(viewModel.points.first?.date, oldDate)
        XCTAssertEqual(viewModel.totalIntake, 2_000)
    }

    func testTodayFilterUsesLocalCalendarDayAcrossDaylightSaving() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 18))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 15))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: morning)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: morning)!

        XCTAssertTrue(DateHelpers.isWithin(morning, period: .oneDay, endingAt: now, calendar: calendar))
        XCTAssertFalse(DateHelpers.isWithin(yesterday, period: .oneDay, endingAt: now, calendar: calendar))
        XCTAssertFalse(DateHelpers.isWithin(tomorrow, period: .allTime, endingAt: now, calendar: calendar))
        XCTAssertEqual(DateHelpers.dates(in: .sevenDays, endingAt: now, calendar: calendar).count, 7)
    }

    func testWeightAnalyticsFiltersSelectedRangeAndCalculatesChange() {
        let endingAt = fixedDate(year: 2026, month: 8, day: 20)
        let weights = [
            WeightEntry(date: fixedDate(year: 2026, month: 8, day: 1), weightKg: 82),
            WeightEntry(date: fixedDate(year: 2026, month: 8, day: 15), weightKg: 80),
            WeightEntry(date: endingAt, weightKg: 79)
        ]
        let viewModel = WeightAnalyticsViewModel(
            weights: weights,
            usesMetricUnits: true,
            period: .sevenDays,
            endingAt: endingAt
        )

        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertEqual(viewModel.weightChangeKg ?? 0, -1, accuracy: 0.001)
        XCTAssertEqual(viewModel.displayWeightChange ?? 0, -1, accuracy: 0.001)
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            sex: .female,
            dateOfBirth: fixedDate(year: 1990, month: 1, day: 1),
            heightCm: 168,
            weightKg: 70,
            activityLevel: .moderatelyActive,
            fitnessGoal: .maintainWeight
        )
    }

    private func fixedDate(year: Int, month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }
}
