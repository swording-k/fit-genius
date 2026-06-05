import Foundation

enum WorkoutCycleCalculator {
    static func daysSinceStart(
        creationDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: creationDate)
        let reference = calendar.startOfDay(for: referenceDate)
        return max(0, calendar.dateComponents([.day], from: start, to: reference).day ?? 0)
    }

    static func cyclePosition(
        creationDate: Date,
        cycleDays: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let safeCycleDays = max(cycleDays, 1)
        return daysSinceStart(
            creationDate: creationDate,
            referenceDate: referenceDate,
            calendar: calendar
        ) % safeCycleDays
    }

    static func cycleWeek(
        creationDate: Date,
        cycleDays: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let safeCycleDays = max(cycleDays, 1)
        return daysSinceStart(
            creationDate: creationDate,
            referenceDate: referenceDate,
            calendar: calendar
        ) / safeCycleDays + 1
    }
}
