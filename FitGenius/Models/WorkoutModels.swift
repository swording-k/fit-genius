import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var userId: String?  // 用户 ID（为用户系统预留）
    var creationDate: Date
    var name: String
    
    @Relationship(inverse: \UserProfile.workoutPlan)
    var userProfile: UserProfile?
    
    @Relationship(deleteRule: .cascade)
    var days: [WorkoutDay]? = []  // ✅ CloudKit 兼容：可选数组
    
    init(name: String = "My Workout Plan", creationDate: Date = Date()) {
        self.userId = nil
        self.name = name
        self.creationDate = creationDate
    }
    
    // 循环天数
    var cycleDays: Int {
        return days?.count ?? 0  // ✅ 处理可选
    }
    
    // 获取今天在循环中的位置（0-based）
    func getTodayCyclePosition() -> Int {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        return daysSinceStart % max(cycleDays, 1)
    }
    
    // 获取今天的训练日
    func getTodayWorkout() -> WorkoutDay? {
        let position = getTodayCyclePosition()
        let sortedDays = days.sorted(by: { $0.dayNumber < $1.dayNumber })
        return sortedDays[safe: position]
    }
    
    // 获取当前是第几个循环周期
    func getCurrentCycleWeek() -> Int {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        return (daysSinceStart / max(cycleDays, 1)) + 1
    }
    
    // 获取指定天数对应的日期
    func getDateForDay(dayNumber: Int) -> Date {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        let currentCycle = daysSinceStart / max(cycleDays, 1)
        let daysToAdd = currentCycle * cycleDays + (dayNumber - 1)
        return calendar.date(byAdding: .day, value: daysToAdd, to: creationDate) ?? Date()
    }
}

@Model
final class WorkoutDay {
    var dayNumber: Int // 1, 2, 3...
    var focus: BodyPartFocus
    var isRestDay: Bool = false  // 是否是休息日
    
    @Relationship(inverse: \WorkoutPlan.days)
    var plan: WorkoutPlan?
    
    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]? = []  // ✅ CloudKit 兼容：可选数组
    
    init(dayNumber: Int, focus: BodyPartFocus, isRestDay: Bool = false) {
        self.dayNumber = dayNumber
        self.focus = focus
        self.isRestDay = isRestDay
    }
}

@Model
final class Exercise {
    var name: String
    var sets: Int
    var reps: String // "8-12", "Failure", "30s"
    var weight: Double // Target weight
    var notes: String
    var isCompleted: Bool
    var lastCompletedDate: Date?
    
    @Relationship(inverse: \WorkoutDay.exercises)
    var workoutDay: WorkoutDay?
    
    @Relationship(deleteRule: .cascade)
    var logs: [ExerciseLog]? = []  // ✅ CloudKit 兼容：可选数组
    
    init(name: String, sets: Int, reps: String, weight: Double = 0, notes: String = "", isCompleted: Bool = false) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.isCompleted = isCompleted
        self.lastCompletedDate = nil
    }
    
    // 切换完成状态（需要传入 ModelContext 来创建 Log）
    func toggleCompletion(context: ModelContext) {
        isCompleted.toggle()
        if isCompleted {
            lastCompletedDate = Date()
            // 创建训练记录
            let log = ExerciseLog(
                date: Date(),
                actualWeight: weight,
                actualSets: sets,
                actualReps: reps
            )
            log.exercise = self
            logs.append(log)
            context.insert(log)
        }
    }
    
    // 检查是否需要重置（如果是昨天完成的，今天重置）
    func resetIfNeeded() {
        guard let lastDate = lastCompletedDate else { return }
        
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastDate) {
            isCompleted = false
        }
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
