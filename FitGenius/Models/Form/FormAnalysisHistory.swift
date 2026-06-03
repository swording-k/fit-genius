import Foundation

struct FormAnalysisListItem: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let exerciseName: String
    let exerciseType: FormExerciseType
    let score: Int
    let issueCount: Int
    let recommendation: String
}

struct FormAnalysisHistorySummary {
    let records: [FormAnalysisListItem]

    var recentRecords: [FormAnalysisListItem] {
        records.sorted { $0.date > $1.date }
    }

    var averageScore: Int {
        guard !records.isEmpty else { return 0 }
        let total = records.reduce(0) { $0 + $1.score }
        return Int((Double(total) / Double(records.count)).rounded())
    }
}
