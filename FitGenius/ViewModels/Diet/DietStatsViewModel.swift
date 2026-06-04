import Foundation
import SwiftData
import Combine

@MainActor
class DietStatsViewModel: ObservableObject {
    @Published var points: [DailyNutritionPoint] = []
    @Published var todayCalories: Double = 0
    @Published var todayProtein: Double = 0
    @Published var todayCarbs: Double = 0
    @Published var todayFat: Double = 0
    @Published var todayNotes: String = ""

    var todayMacroShare: DietMacroCalorieShare {
        DietStatsCalculator.macroCalorieShare(protein: todayProtein, carbs: todayCarbs, fat: todayFat)
    }
    var recentPoints: [DailyNutritionPoint] { Array(points.suffix(5).reversed()) }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadData() {
        let descriptor = FetchDescriptor<MealDay>(sortBy: [SortDescriptor(\.date)])
        guard let days = try? modelContext.fetch(descriptor) else { return }
        var inputs: [DietNutritionInput] = []
        let today = Calendar.current.startOfDay(for: Date())
        var tNotes: String = ""
        for day in days {
            let c = day.summary?.totalCalories ?? (day.entries ?? []).reduce(0) { $0 + $1.calories }
            let p = day.summary?.protein ?? (day.entries ?? []).reduce(0) { $0 + $1.protein }
            let carb = day.summary?.carbs ?? (day.entries ?? []).reduce(0) { $0 + $1.carbs }
            let f = day.summary?.fat ?? (day.entries ?? []).reduce(0) { $0 + $1.fat }
            inputs.append(DietNutritionInput(
                date: day.date,
                calories: c,
                protein: p,
                carbs: carb,
                fat: f,
                notes: day.summary?.notes ?? ""
            ))
            if Calendar.current.isDate(day.date, inSameDayAs: today) {
                if let notes = day.summary?.notes, !notes.isEmpty { tNotes = notes }
            }
        }
        let pts = DietStatsCalculator.aggregate(inputs)
        let todayPoint = pts.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        points = pts
        todayCalories = todayPoint?.calories ?? 0
        todayProtein = todayPoint?.protein ?? 0
        todayCarbs = todayPoint?.carbs ?? 0
        todayFat = todayPoint?.fat ?? 0
        todayNotes = tNotes
    }
}
