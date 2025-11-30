import Foundation
import SwiftData
import Combine

struct DailyNutritionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

@MainActor
class DietStatsViewModel: ObservableObject {
    @Published var points: [DailyNutritionPoint] = []
    @Published var todayCalories: Double = 0
    @Published var todayProtein: Double = 0
    @Published var todayCarbs: Double = 0
    @Published var todayFat: Double = 0
    @Published var todayNotes: String = ""

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadData() {
        let descriptor = FetchDescriptor<MealDay>(sortBy: [SortDescriptor(\.date)])
        guard let days = try? modelContext.fetch(descriptor) else { return }
        var pts: [DailyNutritionPoint] = []
        let today = Calendar.current.startOfDay(for: Date())
        var tC: Double = 0
        var tP: Double = 0
        var tCarb: Double = 0
        var tF: Double = 0
        var tNotes: String = ""
        for day in days {
            let c = day.summary?.totalCalories ?? day.entries.reduce(0) { $0 + $1.calories }
            let p = day.summary?.protein ?? day.entries.reduce(0) { $0 + $1.protein }
            let carb = day.summary?.carbs ?? day.entries.reduce(0) { $0 + $1.carbs }
            let f = day.summary?.fat ?? day.entries.reduce(0) { $0 + $1.fat }
            pts.append(DailyNutritionPoint(date: day.date, calories: c, protein: p, carbs: carb, fat: f))
            if Calendar.current.isDate(day.date, inSameDayAs: today) {
                tC = c; tP = p; tCarb = carb; tF = f
                tNotes = day.summary?.notes ?? ""
            }
        }
        points = pts
        todayCalories = tC
        todayProtein = tP
        todayCarbs = tCarb
        todayFat = tF
        todayNotes = tNotes
    }
}