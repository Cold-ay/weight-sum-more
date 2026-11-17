import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import FitnessTracker

@MainActor
final class LogInsightsTests: XCTestCase {
    func testExerciseStreakCountsDaysRatherThanSessions() {
        let entries = [workout(1), workout(1), workout(2), workout(4), workout(5), workout(6)]
        let insights = ExerciseInsights(entries: entries)
        XCTAssertEqual(insights.activeDays, 5)
        XCTAssertEqual(insights.longestStreak, 3)
        XCTAssertEqual(insights.minutes, 180)
        XCTAssertEqual(ExerciseType.gym.category, .strength)
        XCTAssertEqual(ExerciseType.yoga.category, .mindAndBody)
    }

    func testMealsGroupByDayAndAverageOnlyRecordedDays() {
        let entries = [
            CalorieIntakeEntry(date: date(1), calories: 300, mealCategory: .breakfast),
            CalorieIntakeEntry(date: date(1), calories: 600, mealCategory: .lunch),
            CalorieIntakeEntry(date: date(3), calories: 1_500)
        ]
        let insights = MealInsights(entries: entries)
        XCTAssertEqual(insights.days.count, 2)
        XCTAssertEqual(insights.average ?? 0, 1_200, accuracy: 0.001)
        XCTAssertEqual(insights.total(for: .breakfast), 300)
        XCTAssertEqual(entries.last?.mealCategory, .dailyTotal)
    }

    func testMovingAverageWeightsEachDayEquallyAndUsesOnlySevenCalendarDays() {
        let current = WeightEntry(date: date(8), weightKg: 68)
        let entries = [
            WeightEntry(date: date(1), weightKg: 70),
            WeightEntry(date: date(1), weightKg: 90),
            WeightEntry(date: date(2), weightKg: 72), current,
            WeightEntry(date: date(9), weightKg: 100)
        ]
        let insights = WeightInsights(entries: [current], allEntries: entries)
        XCTAssertEqual(insights.averagePoints.first?.weightKg ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(WeightInsights(entries: Array(entries.prefix(2)), allEntries: entries).recordedDays, 1)
    }

    func testMealCategoriesPersistAndCannotDoubleCountDailyTotal() throws {
        let container = try ModelContainer(for: UserProfile.self, DailyLog.self, ExerciseEntry.self, CalorieIntakeEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let profile = UserProfile(sex: .male, dateOfBirth: date(1).addingTimeInterval(-30 * 365 * 86_400),
                                  heightCm: 175, weightKg: 75, activityLevel: .lightlyActive, fitnessGoal: .maintainWeight)
        context.insert(profile)
        try FitnessDataService.saveCalorieIntake(profile: profile, entry: nil, date: date(1), calories: 300,
                                                notes: "", mealCategory: .breakfast, in: context)
        try FitnessDataService.saveCalorieIntake(profile: profile, entry: nil, date: date(1), calories: 600,
                                                notes: "", mealCategory: .lunch, in: context)
        try FitnessDataService.saveCalorieIntake(profile: profile, entry: nil, date: date(1), calories: 900, notes: "", in: context)
        let saved = try ModelContext(container).fetch(FetchDescriptor<CalorieIntakeEntry>())
        XCTAssertEqual(Set(saved.map(\.mealCategory)), [.breakfast, .lunch, .dailyTotal])
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyLog>()).first?.calorieIntake, 900)
        try FitnessDataService.saveCalorieIntake(profile: profile, entry: nil, date: date(1), calories: 300,
                                                notes: "", mealCategory: .dinner, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyLog>()).first?.calorieIntake, 1_200)
    }

    func testTrendBucketsKeepTotalsWithoutListingEveryEntry() {
        let workouts = (1...28).map(workout)
        let points = PeriodTrends.training(workouts, bucket: .month)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.reduce(0) { $0 + $1.value }, 840)
        let intake = [
            CalorieIntakeEntry(date: date(1), calories: 1_000),
            CalorieIntakeEntry(date: date(1), calories: 300, mealCategory: .breakfast),
            CalorieIntakeEntry(date: date(1), calories: 600, mealCategory: .lunch),
            CalorieIntakeEntry(date: date(2), calories: 500, mealCategory: .dinner)
        ]
        let trend = PeriodTrends.nutrition(intake, bucket: .month)
        XCTAssertEqual(trend.reduce(0) { $0 + $1.value }, 1_500)
        XCTAssertEqual(trend.first { $0.series == MealCategory.dailyTotal.rawValue }?.value, 100)
        XCTAssertEqual(IntakeAggregation.total(intake), 1_500)
        XCTAssertEqual(TrendBucket.choose(period: .ninetyDays, dates: []), .week)
        XCTAssertEqual(TrendBucket.choose(period: .oneYear, dates: []), .month)
    }

    func testCustomWeightGoalsPersistPerProfileAndPeriod() throws {
        let user = UUID()
        let other = UUID()
        var preferences = WeightGoalPreferences.decode(Data())
        XCTAssertNil(preferences.target(profileID: user, period: .thirtyDays))
        try preferences.set(12, profileID: user, period: .thirtyDays)
        try preferences.set(3, profileID: user, period: .sevenDays)
        XCTAssertThrowsError(try preferences.set(0, profileID: user, period: .thirtyDays))
        let restored = WeightGoalPreferences.decode(try preferences.encoded())
        XCTAssertEqual(restored.target(profileID: user, period: .thirtyDays), 12)
        XCTAssertEqual(restored.target(profileID: user, period: .sevenDays), 3)
        XCTAssertNil(restored.target(profileID: other, period: .thirtyDays))
        try preferences.set(nil, profileID: user, period: .thirtyDays)
        XCTAssertNil(preferences.target(profileID: user, period: .thirtyDays))
    }

    func testTrainingCategoryPersistsIndependentlyOfEffort() throws {
        let container = try ModelContainer(for: UserProfile.self, DailyLog.self, ExerciseEntry.self, CalorieIntakeEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let profile = UserProfile(sex: .male, dateOfBirth: date(1).addingTimeInterval(-30 * 365 * 86_400),
                                  heightCm: 175, weightKg: 75, activityLevel: .lightlyActive, fitnessGoal: .maintainWeight)
        container.mainContext.insert(profile)
        try FitnessDataService.saveExercise(profile: profile, entry: nil, date: date(1), exerciseType: .other,
                                           durationMinutes: 30, intensity: .high, caloriesBurned: 100, notes: "",
                                           category: .mindAndBody, in: container.mainContext)
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<ExerciseEntry>()).first)
        XCTAssertEqual(saved.trainingCategory, .mindAndBody)
        XCTAssertEqual(saved.intensity, .high)
        XCTAssertEqual(PeriodTrends.training([saved], bucket: .day).first?.series, ExerciseCategory.mindAndBody.rawValue)
    }

    func testChineseLocalizationIsBundled() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "zh-Hant", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(bundle.localizedString(forKey: "Training", value: nil, table: "Localizable"), "訓練")
        XCTAssertEqual(bundle.localizedString(forKey: "Breakfast", value: nil, table: "Localizable"), "早餐")
        XCTAssertEqual(bundle.localizedString(forKey: "Goals", value: nil, table: "Localizable"), "目標")
        XCTAssertEqual(bundle.localizedString(forKey: "Food portions", value: nil, table: "Localizable"), "食物份量")
    }

    func testMealCategorySurvivesReopeningLocalStore() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = ModelConfiguration(url: folder.appendingPathComponent("meals.store"))
        do {
            let container = try ModelContainer(for: CalorieIntakeEntry.self, configurations: configuration)
            container.mainContext.insert(CalorieIntakeEntry(date: date(1), calories: 1_800))
            container.mainContext.insert(CalorieIntakeEntry(date: date(2), calories: 600, mealCategory: .lunch))
            try container.mainContext.save()
        }
        let reopened = try ModelContainer(for: CalorieIntakeEntry.self, configurations: configuration)
        let saved = try reopened.mainContext.fetch(FetchDescriptor<CalorieIntakeEntry>(sortBy: [SortDescriptor(\CalorieIntakeEntry.date)]))
        XCTAssertEqual(saved.count, 2)
        XCTAssertEqual(saved[0].mealCategory, .dailyTotal)
        XCTAssertEqual(saved[1].mealCategory, .lunch)
        XCTAssertEqual(saved[1].calories, 600)
    }

    func testChineseLogScreensRenderAtPhoneWidth() throws {
        let schema = Schema([UserProfile.self, DailyLog.self, ExerciseEntry.self, CalorieIntakeEntry.self, WeightEntry.self, MonthlyGoal.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let profile = UserProfile(sex: .male, dateOfBirth: date(1).addingTimeInterval(-30 * 365 * 86_400),
                                  heightCm: 175, weightKg: 75, activityLevel: .lightlyActive, fitnessGoal: .maintainWeight)
        context.insert(profile)
        for day in 1...8 {
            context.insert(workout(day))
            context.insert(WeightEntry(date: date(day), weightKg: 75 - Double(day) / 10))
            context.insert(CalorieIntakeEntry(date: date(day), calories: 450, mealCategory: .breakfast))
        }
        try context.save()
        let previousLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        let previousGoals = UserDefaults.standard.data(forKey: "weightRecordingGoals")
        var recordingGoals = WeightGoalPreferences.decode(Data())
        try recordingGoals.set(12, profileID: profile.id, period: .thirtyDays)
        UserDefaults.standard.set(try recordingGoals.encoded(), forKey: "weightRecordingGoals")
        UserDefaults.standard.set("zh-Hant", forKey: "appLanguage")
        defer {
            if let previousLanguage { UserDefaults.standard.set(previousLanguage, forKey: "appLanguage") }
            else { UserDefaults.standard.removeObject(forKey: "appLanguage") }
            if let previousGoals { UserDefaults.standard.set(previousGoals, forKey: "weightRecordingGoals") }
            else { UserDefaults.standard.removeObject(forKey: "weightRecordingGoals") }
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let healthPreview = HealthWorkoutRecord(id: UUID(), startDate: date(8), endDate: date(8).addingTimeInterval(1_800),
                                               durationSeconds: 1_800, energyKcal: nil, exerciseType: .other,
                                               suggestedCategory: nil, activityName: "Health workout", sourceName: "Apple Watch")
        for (name, view) in [
            ("Training-zh-Hant", AnyView(ExerciseLogView(profile: profile))),
            ("Home-text-only-zh-Hant", AnyView(DashboardView(profile: profile))),
            ("Health-import-zh-Hant", AnyView(HealthImportView(profile: profile))),
            ("Health-preview-zh-Hant", AnyView(HealthImportView(profile: profile, initialRecords: [healthPreview]))),
            ("Food-guide-zh-Hant", AnyView(FoodCalorieGuideView())),
            ("Food-label-zh-Hant", AnyView(NavigationStack { VitalityScreen(title: "Add Calories") { FoodPortionCalculator(startWithLabel: true) { _, _ in } } })),
            ("Nutrition-zh-Hant", AnyView(CaloriesLogView(profile: profile))),
            ("Weight-zh-Hant", AnyView(WeightTrackingView(profile: profile))),
            ("Weight-goal-zh-Hant", AnyView(VStack { WeightRecordingGoalView(profileID: profile.id, period: .thirtyDays, count: 8) }.padding().background(VitalityTheme.background))),
            ("More-zh-Hant", AnyView(MoreView(profile: profile))),
            ("Goals-zh-Hant", AnyView(NavigationStack { GoalsView(profile: profile) })),
            ("Training-editor-zh-Hant", AnyView(ExerciseEditorView(entry: nil, profile: profile))),
            ("Nutrition-editor-zh-Hant", AnyView(CalorieEditorView(entry: nil, profile: profile))),
            ("Energy-balance-zh-Hant", AnyView(NavigationStack { WeeklySummaryView(profile: profile, section: .balance) })),
            ("Energy-comparison-zh-Hant", AnyView(NavigationStack { WeeklySummaryView(profile: profile, section: .comparison) })),
            ("Weight-estimate-zh-Hant", AnyView(NavigationStack { WeeklySummaryView(profile: profile, section: .weightEstimate) }))
        ] {
            let root = view.modelContainer(container)
                .environment(\.locale, Locale(identifier: "zh-Hant"))
                .environment(\.trackingDate, date(8))
                .preferredColorScheme(.dark)
            let host = UIHostingController(rootView: root)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = host
            window.makeKeyAndVisible()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            host.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private func date(_ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12))!
    }
    private func workout(_ day: Int) -> ExerciseEntry {
        ExerciseEntry(date: date(day), exerciseType: .running, durationMinutes: 30, intensity: .moderate, caloriesBurned: 200)
    }
}
