import Foundation
import SwiftData

@Model
final class UserProfile {
    var userId: String?  // 用户 ID（为用户系统预留）
    var name: String
    var nickname: String?  // 用户自定义昵称
    var avatarData: Data?  // 用户头像图片数据
    var age: Int
    var height: Double // in cm
    var weight: Double // in kg
    var goal: FitnessGoal
    var environment: WorkoutEnvironment
    var availableEquipment: [String]
    var injuries: String

    // v1.5 新增：能力基线校准字段（均为可选，纯加法，兼容 v1.4 单值 goal，不触发迁移）
    var goals: [FitnessGoal]?            // 多选目标；为空时由 AI 提示词回退到 goal
    var biologicalSex: BiologicalSex?   // 生理性别（敏感个人信息，可空/不愿透露）
    var experienceLevel: ExperienceLevel? // 训练经验水平

    // 坚持天数统计
    var streakDays: Int = 0
    var lastCompletedDate: Date?
    var lastCheckDate: Date?
    
    @Relationship(deleteRule: .cascade)
    var workoutPlan: WorkoutPlan?
    
    init(name: String, age: Int, height: Double, weight: Double, goal: FitnessGoal, environment: WorkoutEnvironment, availableEquipment: [String] = [], injuries: String = "") {
        self.userId = nil
        self.name = name
        self.nickname = nil
        self.avatarData = nil
        self.age = age
        self.height = height
        self.weight = weight
        self.goal = goal
        self.environment = environment
        self.availableEquipment = availableEquipment
        self.injuries = injuries
        self.streakDays = 0
        self.lastCompletedDate = nil
        self.lastCheckDate = nil
    }
    
    // 更新坚持天数
    func updateStreakDays(workoutPlan: WorkoutPlan?) {
        guard let plan = workoutPlan else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 获取今天对应的训练日 (1-7)
        let weekday = calendar.component(.weekday, from: Date())
        let todayDayNumber = weekday == 1 ? 7 : weekday - 1
        
        // 获取今天的训练
        guard let todayWorkout = (plan.days ?? []).first(where: { $0.dayNumber == todayDayNumber }) else {
            return
        }
        
        // 检查今天是否全部完成
        let allCompleted = !(todayWorkout.exercises ?? []).isEmpty &&
                          (todayWorkout.exercises ?? []).allSatisfy { $0.isCompleted }
        
        if allCompleted {
            // 如果今天还没有记录完成，增加天数
            if lastCompletedDate != today {
                streakDays += 1
                lastCompletedDate = today
            }
        } else {
            // 检查是否连续 2 天未完成
            if let lastCheck = lastCheckDate {
                let daysDiff = calendar.dateComponents([.day], from: lastCheck, to: today).day ?? 0
                if daysDiff >= 2 && lastCompletedDate != today {
                    streakDays = 0
                }
            }
        }
        
        lastCheckDate = today
    }
}
