import SwiftUI
import SwiftData

@main
struct WeightSumMoreApp: App {
    @AppStorage("appLanguage") private var language = AppLanguage.system.rawValue
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: (AppLanguage(rawValue: language) ?? .system).identifier))
                .id(language)
        }
        .modelContainer(for: [
            UserProfile.self,
            DailyLog.self,
            ExerciseEntry.self,
            WeightEntry.self,
            CalorieIntakeEntry.self,
            MonthlyGoal.self
        ])
    }
}
