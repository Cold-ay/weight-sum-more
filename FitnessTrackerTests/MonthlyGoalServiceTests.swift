import XCTest
@testable import FitnessTracker

final class MonthlyGoalServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testWorkoutGoalCountsOnlyExercisesInGoalMonth() {
        let goal = MonthlyGoal(month: date(2026, 8, 1), type: .workouts, targetValue: 12)
        let exercises = (1...8).map {
            ExerciseEntry(
                date: date(2026, 8, $0),
                exerciseType: .running,
                durationMinutes: 30,
                intensity: .moderate,
                caloriesBurned: 200
            )
        } + [
            ExerciseEntry(
                date: date(2026, 7, 31),
                exerciseType: .walking,
                durationMinutes: 30,
                intensity: .low,
                caloriesBurned: 100
            )
        ]

        let progress = MonthlyGoalService.progress(
            for: goal,
            exercises: exercises,
            asOf: date(2026, 8, 20),
            calendar: calendar
        )

        XCTAssertEqual(progress.currentValue, 8)
        XCTAssertEqual(progress.targetValue, 12)
        XCTAssertEqual(progress.fractionComplete, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(progress.daysRemaining, 11)
        XCTAssertEqual(progress.requiredDailyPace, 4.0 / 11.0, accuracy: 0.001)
        XCTAssertTrue(progress.isOnPace)
        XCTAssertFalse(progress.isComplete)
    }

    func testActiveMinuteGoalSumsDurationAndReportsCompletion() {
        let goal = MonthlyGoal(month: date(2026, 8, 1), type: .activeMinutes, targetValue: 90)
        let exercises = [
            ExerciseEntry(date: date(2026, 8, 2), exerciseType: .gym, durationMinutes: 45, intensity: .high, caloriesBurned: 300),
            ExerciseEntry(date: date(2026, 8, 4), exerciseType: .yoga, durationMinutes: 50, intensity: .low, caloriesBurned: 120)
        ]

        let progress = MonthlyGoalService.progress(
            for: goal,
            exercises: exercises,
            asOf: date(2026, 8, 5),
            calendar: calendar
        )

        XCTAssertEqual(progress.currentValue, 95)
        XCTAssertEqual(progress.fractionComplete, 1)
        XCTAssertEqual(progress.requiredDailyPace, 0)
        XCTAssertTrue(progress.isComplete)
        XCTAssertTrue(progress.isOnPace)
    }

    func testFutureGoalHasNoElapsedProgress() {
        let goal = MonthlyGoal(month: date(2026, 9, 1), type: .workouts, targetValue: 10)

        let progress = MonthlyGoalService.progress(
            for: goal,
            exercises: [],
            asOf: date(2026, 8, 20),
            calendar: calendar
        )

        XCTAssertEqual(progress.elapsedFraction, 0)
        XCTAssertTrue(progress.isOnPace)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
