import Foundation

struct WatchExercise: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let sets: Int
    let reps: String
    let weight: Double
    var isCompleted: Bool
}

struct WatchWorkoutContext: Codable, Equatable {
    let title: String
    let focus: String
    let isRestDay: Bool
    var exercises: [WatchExercise]

    var completedCount: Int { exercises.filter(\.isCompleted).count }
}
