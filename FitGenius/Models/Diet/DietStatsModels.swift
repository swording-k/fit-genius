import Foundation

struct DailyNutritionPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct DietNutritionInput {
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let notes: String
}

struct DietMacroCalorieShare {
    let protein: Double
    let carbs: Double
    let fat: Double
}

enum DietStatsCalculator {
    static func aggregate(
        _ inputs: [DietNutritionInput],
        calendar: Calendar = .current
    ) -> [DailyNutritionPoint] {
        let meaningful = inputs.filter {
            $0.calories > 0 || $0.protein > 0 || $0.carbs > 0 || $0.fat > 0 || !$0.notes.isEmpty
        }
        let grouped = Dictionary(grouping: meaningful) { calendar.startOfDay(for: $0.date) }
        return grouped.map { date, values in
            DailyNutritionPoint(
                date: date,
                calories: values.reduce(0) { $0 + $1.calories },
                protein: values.reduce(0) { $0 + $1.protein },
                carbs: values.reduce(0) { $0 + $1.carbs },
                fat: values.reduce(0) { $0 + $1.fat }
            )
        }
        .sorted { $0.date < $1.date }
    }

    static func macroCalorieShare(protein: Double, carbs: Double, fat: Double) -> DietMacroCalorieShare {
        let proteinCalories = max(0, protein) * 4
        let carbCalories = max(0, carbs) * 4
        let fatCalories = max(0, fat) * 9
        let total = proteinCalories + carbCalories + fatCalories
        guard total > 0 else {
            return DietMacroCalorieShare(protein: 0, carbs: 0, fat: 0)
        }
        return DietMacroCalorieShare(
            protein: proteinCalories / total,
            carbs: carbCalories / total,
            fat: fatCalories / total
        )
    }
}
