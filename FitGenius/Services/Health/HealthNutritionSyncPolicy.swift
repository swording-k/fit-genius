import Foundation

/// Maps the locally confirmed daily nutrition total to stable HealthKit sample identities.
/// Keeping this free of HealthKit makes duplicate-prevention behavior unit-testable.
enum HealthNutritionSyncPolicy {
    enum Metric: String, CaseIterable {
        case energy
        case protein
        case carbs
        case fat
    }

    struct Sample: Equatable {
        let identifier: String
        let metric: Metric
        let value: Double
    }

    static func samples(date: Date, calories: Double, protein: Double, carbs: Double, fat: Double) -> [Sample] {
        let values: [(Metric, Double)] = [
            (.energy, calories),
            (.protein, protein),
            (.carbs, carbs),
            (.fat, fat)
        ]

        return values.map { metric, value in
            Sample(
                identifier: "fitgenius-nutrition-\(dayToken(for: date))-\(metric.rawValue)",
                metric: metric,
                value: max(0, value)
            )
        }
    }

    static func dayToken(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
