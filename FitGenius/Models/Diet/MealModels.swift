import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"
}

@Model final class MealEntry {
    var date: Date
    var mealType: MealType
    var text: String
    var images: [Data]
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var source: String
    var day: MealDay?

    init(date: Date = Date(),
         mealType: MealType,
         text: String = "",
         images: [Data] = [],
         calories: Double = 0,
         protein: Double = 0,
         carbs: Double = 0,
         fat: Double = 0,
         source: String = "user") {
        self.date = date
        self.mealType = mealType
        self.text = text
        self.images = images
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.source = source
    }
}

@Model final class MealDay {
    var date: Date
    var entries: [MealEntry]
    var submitted: Bool
    var summary: NutritionSummary?

    init(date: Date = Calendar.current.startOfDay(for: Date()), entries: [MealEntry] = [], submitted: Bool = false) {
        self.date = date
        self.entries = entries
        self.submitted = submitted
    }
}

@Model final class NutritionSummary {
    var date: Date
    var totalCalories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var notes: String
    var day: MealDay?

    init(date: Date,
         totalCalories: Double,
         protein: Double,
         carbs: Double,
         fat: Double,
         notes: String = "") {
        self.date = date
        self.totalCalories = totalCalories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.notes = notes
    }
}