import Foundation
import SwiftData

enum SampleData {
    @MainActor
    static func previewContainer() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            DailyLog.self,
            ExerciseEntry.self,
            WeightEntry.self,
            CalorieIntakeEntry.self,
            MonthlyGoal.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        seed(into: container.mainContext)
        return container
    }

    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let birthDate = calendar.date(from: DateComponents(year: 1992, month: 4, day: 12)) ?? Date()
        let profile = UserProfile(
            sex: .female,
            dateOfBirth: birthDate,
            heightCm: 168,
            weightKg: 68,
            bodyFatPercentage: 28,
            activityLevel: .moderatelyActive,
            fitnessGoal: .maintainWeight
        )
        context.insert(profile)
        context.insert(MonthlyGoal(
            month: calendar.dateInterval(of: .month, for: Date())?.start ?? Date(),
            type: .workouts,
            targetValue: 12
        ))

        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            context.insert(CalorieIntakeEntry(date: date, calories: 2050 + Double(offset * 35), notes: "Sample day"))
            context.insert(ExerciseEntry(date: date, exerciseType: .walking, durationMinutes: 35, intensity: .moderate, caloriesBurned: 180))
        }

        context.insert(WeightEntry(date: Date(), weightKg: 68))
        if let earlier = calendar.date(byAdding: .day, value: -14, to: Date()) {
            context.insert(WeightEntry(date: earlier, weightKg: 68.8))
        }
    }
}
