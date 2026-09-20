import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct HealthReportWeekRangeTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let sundayNoon = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 12))!
        let nextMonday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 0))!

        let range = HealthReportWeekRange.current(containing: sundayNoon, calendar: calendar)
        require(range.contains(sundayNoon), "the current week must include all of Sunday")
        require(!range.contains(nextMonday), "the current week must exclude the following Monday")

        print("health-report-week-range-tests: PASS")
    }
}
