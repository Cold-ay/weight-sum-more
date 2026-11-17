import Foundation

enum DateHelpers {
    static func isSameDay(_ first: Date, _ second: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(first, inSameDayAs: second)
    }

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func lastSevenDays(endingAt date: Date = Date(), calendar: Calendar = .current) -> [Date] {
        dates(in: .sevenDays, endingAt: date, calendar: calendar)
    }

    static func dates(in period: AnalyticsPeriod, endingAt date: Date = Date(), calendar: Calendar = .current) -> [Date] {
        guard period != .allTime else { return [] }
        return (0..<period.dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: startOfDay(date, calendar: calendar))
        }
        .reversed()
    }

    static func dates(from startDate: Date, through endDate: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let start = startOfDay(startDate, calendar: calendar)
        let end = startOfDay(endDate, calendar: calendar)
        guard start <= end else { return [] }

        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    static func isWithin(_ date: Date, period: AnalyticsPeriod, endingAt endingDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: startOfDay(endingDate, calendar: calendar)) else {
            return false
        }
        if period == .allTime {
            return date < endExclusive
        }
        guard let startDate = calendar.date(
            byAdding: .day, value: -(period.dayCount - 1), to: startOfDay(endingDate, calendar: calendar)
        ) else {
            return false
        }
        return date >= startDate && date < endExclusive
    }
}
