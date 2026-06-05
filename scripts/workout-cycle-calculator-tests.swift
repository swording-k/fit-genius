import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct WorkoutCycleCalculatorTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!

        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4, hour: 22))!
        let nextMorning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 5, hour: 8))!

        require(
            WorkoutCycleCalculator.daysSinceStart(
                creationDate: start,
                referenceDate: nextMorning,
                calendar: calendar
            ) == 1,
            "cycle should advance on calendar day boundary, not after a full 24 hours"
        )
        require(
            WorkoutCycleCalculator.cyclePosition(
                creationDate: start,
                cycleDays: 7,
                referenceDate: nextMorning,
                calendar: calendar
            ) == 1,
            "next calendar day should select the second workout day"
        )

        let beforeStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 8))!
        require(
            WorkoutCycleCalculator.daysSinceStart(
                creationDate: start,
                referenceDate: beforeStart,
                calendar: calendar
            ) == 0,
            "cycle should not go negative if device date or imported plan date is earlier"
        )

        print("Workout cycle calculator tests passed")
    }
}
