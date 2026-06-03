#if DEBUG
import Foundation
import SwiftData

enum DebugSeedService {
    static let launchArgument = "-FitGeniusSeedFormCoachDemo"

    static var shouldSeedFormCoachDemo: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func seedFormCoachDemoIfNeeded(modelContext: ModelContext) {
        guard shouldSeedFormCoachDemo else { return }

        let descriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(descriptor),
           profiles.contains(where: { $0.name == "Form Coach Demo" }) {
            return
        }

        let profile = UserProfile(
            name: "Form Coach Demo",
            age: 30,
            height: 175,
            weight: 75,
            goal: .buildMuscle,
            environment: .gym,
            availableEquipment: ["杠铃", "卧推架", "哑铃"],
            injuries: ""
        )

        let plan = WorkoutPlan(name: "Form Coach Demo Plan", creationDate: Date())
        let chestDay = WorkoutDay(dayNumber: 1, focus: .chest)
        let benchPress = Exercise(name: "卧推", sets: 4, reps: "8-10", weight: 60, notes: "保持肩胛收紧")
        let squat = Exercise(name: "深蹲", sets: 4, reps: "8-10", weight: 80, notes: "控制下蹲深度")
        let deadlift = Exercise(name: "硬拉", sets: 3, reps: "5", weight: 100, notes: "保持背部张力")

        benchPress.orderIndex = 0
        squat.orderIndex = 1
        deadlift.orderIndex = 2

        plan.userProfile = profile
        profile.workoutPlan = plan
        chestDay.plan = plan
        chestDay.exercises = [benchPress, squat, deadlift]
        plan.days = [chestDay]

        benchPress.workoutDay = chestDay
        squat.workoutDay = chestDay
        deadlift.workoutDay = chestDay

        modelContext.insert(profile)
        modelContext.insert(plan)
        modelContext.insert(chestDay)
        modelContext.insert(benchPress)
        modelContext.insert(squat)
        modelContext.insert(deadlift)

        try? modelContext.save()
    }
}
#endif
