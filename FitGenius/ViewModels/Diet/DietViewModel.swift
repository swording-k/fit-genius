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
    @Published var requiresBackendReconnect: Bool = false

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
        let entry = MealEntry(date: selectedDate,
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
        refreshSummaryFromEntries()
        try? modelContext.save()
        NotificationCenter.default.post(name: .dietSummaryUpdated, object: nil)
        isPresentingEditSheet = false
        editingEntry = nil
    }

    func deleteEntry(_ entry: MealEntry) {
        guard let day = day else { return }
        if let idx = (day.entries ?? []).firstIndex(where: { $0 === entry }) {
            day.entries?.remove(at: idx)
            modelContext.delete(entry)
            refreshSummaryFromEntries()
            try? modelContext.save()
            NotificationCenter.default.post(name: .dietSummaryUpdated, object: nil)
        }
    }

	func submitDayForAnalysis() async {
		guard let day = day, !(day.entries ?? []).isEmpty else { return }
		isSubmitting = true
        requiresBackendReconnect = false
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
            submitAlertMessage = "diet_ai_analysis_success".localized
            showSubmitAlert = true
            NotificationCenter.default.post(name: .dietSummaryUpdated, object: nil)
        } catch {
            let isMissingSession: Bool
            if case AIServiceError.missingSessionToken = error {
                isMissingSession = true
            } else {
                isMissingSession = false
            }

            if DietAnalysisFailurePolicy.classify(isMissingSession: isMissingSession) == .reconnectRequired {
                requiresBackendReconnect = true
                submitAlertMessage = "diet_ai_reconnect_required".localized
                showSubmitAlert = true
                return
            }

            // 降级：对已有数值求和生成汇总
            let c = (day.entries ?? []).reduce(0) { $0 + $1.calories }
            let p = (day.entries ?? []).reduce(0) { $0 + $1.protein }
            let carb = (day.entries ?? []).reduce(0) { $0 + $1.carbs }
            let f = (day.entries ?? []).reduce(0) { $0 + $1.fat }
            let summary = NutritionSummary(date: day.date, totalCalories: c, protein: p, carbs: carb, fat: f)
            summary.day = day
            day.summary = summary
            day.submitted = true
            submitAlertMessage = "diet_ai_fallback_summary".localized(with: error.localizedDescription)
            showSubmitAlert = true
            NotificationCenter.default.post(name: .dietSummaryUpdated, object: nil)
        }
    }

    private func refreshSummaryFromEntries() {
        guard let day else { return }
        let entries = day.entries ?? []
        let calories = entries.reduce(0) { $0 + $1.calories }
        let protein = entries.reduce(0) { $0 + $1.protein }
        let carbs = entries.reduce(0) { $0 + $1.carbs }
        let fat = entries.reduce(0) { $0 + $1.fat }

        guard calories > 0 || protein > 0 || carbs > 0 || fat > 0 else {
            day.summary = nil
            day.submitted = false
            return
        }

        let summary = day.summary ?? NutritionSummary(
            date: day.date,
            totalCalories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
        summary.date = day.date
        summary.totalCalories = calories
        summary.protein = protein
        summary.carbs = carbs
        summary.fat = fat
        summary.day = day
        day.summary = summary
    }
}
