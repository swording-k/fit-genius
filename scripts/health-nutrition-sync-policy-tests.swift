import Foundation

@main
struct HealthNutritionSyncPolicyTests {
    static func main() {
        let day = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 8, day: 3))!
        let samples = HealthNutritionSyncPolicy.samples(
            date: day,
            calories: 2200,
            protein: 160,
            carbs: 240,
            fat: 70
        )

        require(samples.count == 4, "a daily nutrition sync must include calories and all three macros")
        require(samples.map(\.identifier) == [
            "fitgenius-nutrition-2026-08-03-energy",
            "fitgenius-nutrition-2026-08-03-protein",
            "fitgenius-nutrition-2026-08-03-carbs",
            "fitgenius-nutrition-2026-08-03-fat"
        ], "identifiers must be stable per day and nutrient so updates cannot duplicate totals")
        require(samples[0].value == 2200 && samples[1].value == 160, "nutrition values should be carried into the sync payload")

        let clamped = HealthNutritionSyncPolicy.samples(
            date: day,
            calories: -1,
            protein: -2,
            carbs: 3,
            fat: 4
        )
        require(clamped[0].value == 0 && clamped[1].value == 0, "invalid negative nutrition values must never reach HealthKit")

        print("health-nutrition-sync-policy-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
