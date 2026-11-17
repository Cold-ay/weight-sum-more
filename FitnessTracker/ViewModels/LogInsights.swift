import Foundation

struct ExerciseInsights {
    let entries: [ExerciseEntry]
    var minutes: Int { entries.reduce(0) { $0 + $1.durationMinutes } }
    var activeDays: Int { Set(entries.map { DateHelpers.startOfDay($0.date) }).count }
    var favorite: ExerciseType? {
        Dictionary(grouping: entries, by: \.exerciseType)
            .max { left, right in
                let lhs = left.value.reduce(0) { $0 + $1.durationMinutes }
                let rhs = right.value.reduce(0) { $0 + $1.durationMinutes }
                return lhs == rhs ? left.key.rawValue < right.key.rawValue : lhs < rhs
            }?.key
    }

    var longestStreak: Int {
        let days = Set(entries.map { DateHelpers.startOfDay($0.date) }).sorted()
        var longest = 0
        var streak = 0
        var previous: Date?
        for day in days {
            if let previous, Calendar.current.date(byAdding: .day, value: 1, to: previous) == day {
                streak += 1
            } else {
                streak = 1
            }
            longest = max(longest, streak)
            previous = day
        }
        return longest
    }

    func currentStreak(endingAt date: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        let days = Set(entries.filter { calendar.startOfDay(for: $0.date) <= today }.map { calendar.startOfDay(for: $0.date) })
        var cursor = today
        if !days.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}

struct IntakeDay: Identifiable {
    let date: Date
    let entries: [CalorieIntakeEntry]
    var id: Date { date }
    var total: Double { IntakeAggregation.total(entries) }
}

struct MealInsights {
    let entries: [CalorieIntakeEntry]
    var days: [IntakeDay] {
        Dictionary(grouping: entries, by: { DateHelpers.startOfDay($0.date) })
            .map { IntakeDay(date: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }
    var average: Double? {
        guard !days.isEmpty else { return nil }
        return IntakeAggregation.total(entries) / Double(days.count)
    }
    func total(for meal: MealCategory) -> Double {
        if meal == .dailyTotal {
            return days.reduce(0) { result, day in
                result + max(day.total - day.entries.filter { $0.mealCategory != .dailyTotal }.reduce(0) { $0 + $1.calories }, 0)
            }
        }
        return entries.filter { $0.mealCategory == meal }.reduce(0) { $0 + $1.calories }
    }
}

struct WeightAveragePoint: Identifiable {
    let date: Date
    let weightKg: Double
    var id: Date { date }
}

struct WeightInsights {
    let entries: [WeightEntry]
    let allEntries: [WeightEntry]
    var recordedDays: Int { Set(entries.map { DateHelpers.startOfDay($0.date) }).count }
    var averagePoints: [WeightAveragePoint] {
        let dailyWeights = Dictionary(grouping: allEntries, by: { DateHelpers.startOfDay($0.date) })
            .mapValues { $0.reduce(0) { $0 + $1.weightKg } / Double($0.count) }
        return Set(entries.map { DateHelpers.startOfDay($0.date) }).sorted().compactMap { day in
            let window = (0..<7).compactMap { offset -> Double? in
                guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: day) else { return nil }
                return dailyWeights[date]
            }
            guard !window.isEmpty else { return nil }
            return WeightAveragePoint(date: day, weightKg: window.reduce(0, +) / Double(window.count))
        }
    }
}
