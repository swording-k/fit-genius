import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class DietViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var day: MealDay?
    @Published var isPresentingAddSheet: Bool = false
    @Published var inputText: String = ""
    @Published var selectedMealType: MealType = .breakfast
    @Published var selectedImagesData: [Data] = []
    @Published var isPresentingEditSheet: Bool = false
    @Published var editingEntry: MealEntry?
    @Published var editText: String = ""
    @Published var editCalories: String = ""
    @Published var editProtein: String = ""
    @Published var editCarbs: String = ""
    @Published var editFat: String = ""
    @Published var isSubmitting: Bool = false
    @Published var showSubmitAlert: Bool = false
    @Published var submitAlertMessage: String = ""

    private let modelContext: ModelContext
    private let service = AIService()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadDay() {
        let start = Calendar.current.startOfDay(for: selectedDate)
        let descriptor = FetchDescriptor<MealDay>(predicate: #Predicate { $0.date == start })
        if let result = try? modelContext.fetch(descriptor).first {
            day = result
        } else {
            let newDay = MealDay(date: start)
            modelContext.insert(newDay)
            day = newDay
        }
    }

    func addMealEntry() {
        guard let day = day else { return }
        let entry = MealEntry(date: Date(),
                              mealType: selectedMealType,
                              text: inputText,
                              images: selectedImagesData,
                              calories: 0,
                              protein: 0,
                              carbs: 0,
                              fat: 0,
                              source: "user")
        entry.day = day
        if day.entries == nil { day.entries = [] }
        day.entries?.append(entry)
        inputText = ""
        selectedImagesData = []
        isPresentingAddSheet = false
    }

    func startEdit(entry: MealEntry) {
        editingEntry = entry
        editText = entry.text
        editCalories = entry.calories == 0 ? "" : String(format: "%.0f", entry.calories)
        editProtein = entry.protein == 0 ? "" : String(format: "%.0f", entry.protein)
        editCarbs = entry.carbs == 0 ? "" : String(format: "%.0f", entry.carbs)
        editFat = entry.fat == 0 ? "" : String(format: "%.0f", entry.fat)
        isPresentingEditSheet = true
    }

    func saveEdit() {
        guard let entry = editingEntry else { return }
        entry.text = editText
        entry.calories = Double(editCalories) ?? entry.calories
        entry.protein = Double(editProtein) ?? entry.protein
        entry.carbs = Double(editCarbs) ?? entry.carbs
        entry.fat = Double(editFat) ?? entry.fat
        isPresentingEditSheet = false
        editingEntry = nil
    }

    func deleteEntry(_ entry: MealEntry) {
        guard let day = day else { return }
        if let idx = (day.entries ?? []).firstIndex(where: { $0 === entry }) {
            day.entries?.remove(at: idx)
            modelContext.delete(entry)
        }
    }

	func submitDayForAnalysis() async {
		guard let day = day, !(day.entries ?? []).isEmpty else { return }
		isSubmitting = true
		defer { isSubmitting = false }
		do {
			let entries = day.entries ?? []
			let hasImages = entries.contains { !$0.images.isEmpty }
			let result: AIService.DietAnalyzeResponse
			if hasImages {
				result = try await service.analyzeMealsWithImages(entries: entries)
			} else {
				result = try await service.analyzeMeals(entries: entries)
			}
			let count = min(entries.count, result.entries.count)
			for index in 0..<count {
				let aiItem = result.entries[index]
				let entry = entries[index]
				entry.calories = aiItem.calories
				entry.protein = aiItem.protein
				entry.carbs = aiItem.carbs
				entry.fat = aiItem.fat
			}
			let summary = NutritionSummary(
				date: day.date,
				totalCalories: result.summary.totalCalories,
				protein: result.summary.protein,
				carbs: result.summary.carbs,
				fat: result.summary.fat,
				notes: result.summary.notes ?? ""
			)
            summary.day = day
            day.summary = summary
            day.submitted = true
            submitAlertMessage = "已根据 AI 分析更新今日饮食统计"
            showSubmitAlert = true
            NotificationCenter.default.post(name: .dietSummaryUpdated, object: nil)
        } catch {
            // 降级：对已有数值求和生成汇总
            let c = (day.entries ?? []).reduce(0) { $0 + $1.calories }
            let p = (day.entries ?? []).reduce(0) { $0 + $1.protein }
            let carb = (day.entries ?? []).reduce(0) { $0 + $1.carbs }
            let f = (day.entries ?? []).reduce(0) { $0 + $1.fat }
            let summary = NutritionSummary(date: day.date, totalCalories: c, protein: p, carbs: carb, fat: f, notes: "AI 不可用，使用本地汇总")
            summary.day = day
            day.summary = summary
            day.submitted = true
            submitAlertMessage = "AI 不可用，已使用本地汇总生成今日统计"
            showSubmitAlert = true
            NotificationCenter.default.post(name: .dietSummaryUpdated, object: nil)
        }
    }
}
