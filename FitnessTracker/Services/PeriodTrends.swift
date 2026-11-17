import Foundation

enum IntakeAggregation {
    static func total(_ entries: [CalorieIntakeEntry]) -> Double {
        Dictionary(grouping: entries, by: { DateHelpers.startOfDay($0.date) }).values.reduce(0) { result, day in
            let meals = day.filter { $0.mealCategory != .dailyTotal }.reduce(0) { $0 + $1.calories }
            let previousEstimate = day.filter { $0.mealCategory == .dailyTotal }.reduce(0) { $0 + $1.calories }
            // Legacy totals are a baseline being itemized, not an extra meal.
            return result + max(meals, previousEstimate)
        }
    }
}

enum TrendBucket: Equatable {
    case day, week, month
    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
    var title: String {
        switch self {
        case .day: "Daily trend".localized
        case .week: "Weekly trend".localized
        case .month: "Monthly trend".localized
        }
    }
    func start(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: component, for: date)?.start ?? calendar.startOfDay(for: date)
    }
    static func choose(period: AnalyticsPeriod, dates: [Date]) -> TrendBucket {
        switch period {
        case .oneDay, .sevenDays, .thirtyDays: return .day
        case .ninetyDays: return .week
        case .oneYear: return .month
        case .allTime:
            if let first = dates.min(), let last = dates.max() {
                let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
                return days > 180 ? .month : days > 45 ? .week : .day
            }
            return .day
        }
    }
}

struct PeriodTrendPoint: Identifiable {
    let date: Date
    let series: String
    let value: Double
    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(series)" }
}

enum PeriodTrends {
    static func training(_ entries: [ExerciseEntry], bucket: TrendBucket) -> [PeriodTrendPoint] {
        let dates = Dictionary(grouping: entries, by: { bucket.start($0.date) })
        return dates.keys.sorted().flatMap { day in
            ExerciseCategory.allCases.compactMap { category in
                let matching = (dates[day] ?? []).filter { $0.trainingCategory == category }
                guard !matching.isEmpty else { return nil }
                return PeriodTrendPoint(date: day, series: category.rawValue, value: Double(matching.reduce(0) { $0 + $1.durationMinutes }))
            }
        }
    }

    static func nutrition(_ entries: [CalorieIntakeEntry], bucket: TrendBucket, meal: MealCategory? = nil) -> [PeriodTrendPoint] {
        let days = MealInsights(entries: entries).days
        var totals: [Date: [MealCategory: Double]] = [:]
        for day in days {
            let insights = MealInsights(entries: day.entries)
            for category in MealCategory.allCases where meal == nil || category == meal {
                let value = insights.total(for: category)
                if value > 0 || day.entries.contains(where: { $0.mealCategory == category }) {
                    totals[bucket.start(day.date), default: [:]][category, default: 0] += value
                }
            }
        }
        return totals.keys.sorted().flatMap { day in
            MealCategory.allCases.compactMap { category in
                guard let value = totals[day]?[category] else { return nil }
                return PeriodTrendPoint(date: day, series: category.rawValue, value: value)
            }
        }
    }

    static func weight(_ points: [WeightAveragePoint], bucket: TrendBucket) -> [WeightAveragePoint] {
        Dictionary(grouping: points, by: { bucket.start($0.date) }).map { day, values in
            WeightAveragePoint(date: day, weightKg: values.reduce(0) { $0 + $1.weightKg } / Double(values.count))
        }.sorted { $0.date < $1.date }
    }

    static func energy(_ points: [CalorieTrendPoint], bucket: TrendBucket) -> [CalorieTrendPoint] {
        Dictionary(grouping: points, by: { bucket.start($0.date) }).map { date, values in
            CalorieTrendPoint(date: date,
                             calorieIntake: values.reduce(0) { $0 + $1.calorieIntake },
                             calorieOutput: values.reduce(0) { $0 + $1.calorieOutput },
                             dailyBalance: values.reduce(0) { $0 + $1.dailyBalance })
        }.sorted { $0.date < $1.date }
    }
}

struct WeightGoalPreferences: Codable {
    private var targets: [String: Int] = [:]
    static func decode(_ data: Data) -> Self { (try? JSONDecoder().decode(Self.self, from: data)) ?? Self() }
    func encoded() throws -> Data { try JSONEncoder().encode(self) }
    func target(profileID: UUID, period: AnalyticsPeriod) -> Int? { targets[key(profileID, period)] }
    mutating func set(_ count: Int?, profileID: UUID, period: AnalyticsPeriod) throws {
        if let count, !(1...10_000).contains(count) { throw WeightGoalError.invalidCount }
        targets[key(profileID, period)] = count
    }
    private func key(_ profileID: UUID, _ period: AnalyticsPeriod) -> String { "\(profileID.uuidString):\(period.rawValue)" }
}

enum WeightGoalError: LocalizedError {
    case invalidCount
    var errorDescription: String? { "Enter a recording goal between 1 and 10,000.".localized }
}
