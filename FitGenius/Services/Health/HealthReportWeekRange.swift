import Foundation

struct HealthReportWeekRange {
    let interval: DateInterval

    var start: Date { interval.start }
    var endExclusive: Date { interval.end }

    func contains(_ date: Date) -> Bool {
        date >= start && date < endExclusive
    }

    static func current(containing date: Date = Date(), calendar: Calendar = .current) -> HealthReportWeekRange {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offsetFromMonday = (weekday - 2 + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offsetFromMonday, to: day) ?? day
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return HealthReportWeekRange(interval: DateInterval(start: start, end: end))
    }
}
