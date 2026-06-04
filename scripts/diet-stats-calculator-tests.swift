import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DietStatsCalculatorTests {
    static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let first = Date(timeIntervalSince1970: 1_780_272_000)
        let laterSameDay = first.addingTimeInterval(3_600)
        let nextDay = first.addingTimeInterval(86_400)

        let points = DietStatsCalculator.aggregate(
            [
                DietNutritionInput(date: first, calories: 500, protein: 30, carbs: 60, fat: 15, notes: "first"),
                DietNutritionInput(date: laterSameDay, calories: 700, protein: 40, carbs: 80, fat: 20, notes: "second"),
                DietNutritionInput(date: nextDay, calories: 900, protein: 50, carbs: 100, fat: 25, notes: ""),
                DietNutritionInput(date: nextDay.addingTimeInterval(86_400), calories: 0, protein: 0, carbs: 0, fat: 0, notes: "")
            ],
            calendar: calendar
        )

        require(points.count == 2, "same-day nutrition records should merge into one chart point")
        require(points[0].calories == 1_200, "merged chart point should sum calories")
        require(points[0].protein == 70, "merged chart point should sum protein")

        let share = DietStatsCalculator.macroCalorieShare(protein: 25, carbs: 25, fat: 10)
        require(abs(share.protein - (100.0 / 290.0)) < 0.001, "protein share should use 4 kcal per gram")
        require(abs(share.carbs - (100.0 / 290.0)) < 0.001, "carb share should use 4 kcal per gram")
        require(abs(share.fat - (90.0 / 290.0)) < 0.001, "fat share should use 9 kcal per gram")

        print("diet-stats-calculator-tests: PASS")
    }
}
