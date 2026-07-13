import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var userId: String?
    var creationDate: Date
    var name: String
    @Relationship(inverse: \UserProfile.workoutPlan)
    var userProfile: UserProfile?
    @Relationship(deleteRule: .cascade)
    var days: [WorkoutDay]? = []
    init(name: String = "My Workout Plan", creationDate: Date = Date()) {
        self.userId = nil
        self.name = name
        self.creationDate = creationDate
    }
    var cycleDays: Int { days?.count ?? 0 }
    func getTodayCyclePosition() -> Int {
        WorkoutCycleCalculator.cyclePosition(
            creationDate: creationDate,
            cycleDays: cycleDays
        )
    }
    func getTodayWorkout() -> WorkoutDay? {
        let position = getTodayCyclePosition()
        let sortedDays = (days ?? []).sorted(by: { $0.dayNumber < $1.dayNumber })
        return sortedDays[safe: position]
    }
    func getCurrentCycleWeek() -> Int {
        WorkoutCycleCalculator.cycleWeek(
            creationDate: creationDate,
            cycleDays: cycleDays
        )
    }
    func getDateForDay(dayNumber: Int) -> Date {
        let calendar = Calendar.current
        let daysSinceStart = WorkoutCycleCalculator.daysSinceStart(creationDate: creationDate)
        let currentCycle = daysSinceStart / max(cycleDays, 1)
        let daysToAdd = currentCycle * cycleDays + (dayNumber - 1)
        let start = calendar.startOfDay(for: creationDate)
        return calendar.date(byAdding: .day, value: daysToAdd, to: start) ?? Date()
    }
}

@Model
final class WorkoutDay {
    var dayNumber: Int
    var focus: BodyPartFocus
    var isRestDay: Bool = false
    @Relationship(inverse: \WorkoutPlan.days)
    var plan: WorkoutPlan?
    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]? = []
    init(dayNumber: Int, focus: BodyPartFocus, isRestDay: Bool = false) {
        self.dayNumber = dayNumber
        self.focus = focus
        self.isRestDay = isRestDay
    }

    var isComplete: Bool {
        let exercises = exercises ?? []
        return !isRestDay && !exercises.isEmpty && exercises.allSatisfy(\.isCompleted)
    }
}

@Model
final class Exercise {
    var name: String
    var sets: Int
    var reps: String
    var weight: Double
    var notes: String
    var isCompleted: Bool
    var lastCompletedDate: Date?
    var orderIndex: Int
    @Relationship(inverse: \WorkoutDay.exercises)
    var workoutDay: WorkoutDay?
    @Relationship(deleteRule: .cascade)
    var logs: [ExerciseLog]? = []
    /// 来源动作模板（动作库）。为空表示手敲的自由动作；非空则可看 GIF、
    /// 标准说明、并作为姿态对照的参考基线。删除模板不影响本动作。
    @Relationship(deleteRule: .nullify)
    var template: ExerciseTemplate?
    init(name: String, sets: Int, reps: String, weight: Double = 0, notes: String = "", isCompleted: Bool = false) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.isCompleted = isCompleted
        self.lastCompletedDate = nil
        self.orderIndex = 0
    }
    func toggleCompletion(context: ModelContext) {
        isCompleted.toggle()
        if isCompleted {
            lastCompletedDate = Date()
            let log = ExerciseLog(
                date: Date(),
                actualWeight: weight,
                actualSets: sets,
                actualReps: reps
            )
            log.exercise = self
            if logs == nil { logs = [] }
            logs?.append(log)
            context.insert(log)
        } else {
            let todayLogs = (logs ?? []).filter { Calendar.current.isDateInToday($0.date) }
            for log in todayLogs {
                context.delete(log)
            }
            logs?.removeAll { Calendar.current.isDateInToday($0.date) }
            lastCompletedDate = logs?.map(\.date).max()
        }
    }
    func resetIfNeeded() {
        guard let lastDate = lastCompletedDate else { return }
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastDate) {
            isCompleted = false
        }
    }

    /// 展示名。与动作库保持一致，跟随**系统语言**：
    /// 只要关联到动作库模板，就复用模板的 `displayName`（它本身按系统语言返回
    /// 中文或英文），因此计划里的动作也会随 iPhone 系统语言切换而中/英切换，
    /// 不会卡在当初加入时存下的那一种语言。无模板（手敲/AI 自由动作）才回退已存 `name`。
    var localizedDisplayName: String {
        if let t = template {
            return t.displayName
        }
        return name
    }
}

@Model
final class ExerciseLog {
    var date: Date
    var actualWeight: Double
    var actualSets: Int
    var actualReps: String
    @Relationship(inverse: \Exercise.logs)
    var exercise: Exercise?
    init(date: Date = Date(), actualWeight: Double, actualSets: Int, actualReps: String) {
        self.date = date
        self.actualWeight = actualWeight
        self.actualSets = actualSets
        self.actualReps = actualReps
    }
}
