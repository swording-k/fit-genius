import Foundation
import SwiftData

@Model
final class MealDay {
    var date: Date
    @Relationship(deleteRule: .cascade) var meals: [Meal] = []
    var analysis: NutritionSummary?
    var updatedAt: Date

    init(date: Date = Calendar.current.startOfDay(for: Date())) {
        self.date = date
        self.updatedAt = Date()
    }
}

@Model
final class Meal {
    var name: String // 早餐/午餐/晚餐/加餐 或自定义
    @Relationship(deleteRule: .cascade) var entries: [MealEntry] = []
    @Relationship(inverse: \MealDay.meals) var day: MealDay?

    init(name: String) { self.name = name }
}

enum MealEntryType: String, Codable, CaseIterable { case text, photo }

@Model
final class MealEntry {
    var typeRaw: String
    var text: String
    var photoLocalURL: String
    var quantity: String
    var notes: String
    @Relationship(inverse: \Meal.entries) var meal: Meal?

    var type: MealEntryType { MealEntryType(rawValue: typeRaw) ?? .text }

    init(type: MealEntryType, text: String = "", photoLocalURL: String = "", quantity: String = "", notes: String = "") {
        self.typeRaw = type.rawValue
        self.text = text
        self.photoLocalURL = photoLocalURL
        self.quantity = quantity
        self.notes = notes
    }
}

@Model
final class NutritionSummary {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var details: [FoodBreakdown]

    init(calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0, details: [FoodBreakdown] = []) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.details = details
    }
}

@Model
final class FoodBreakdown {
    var name: String
    var quantity: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(name: String, quantity: String = "", calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.name = name
        self.quantity = quantity
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}