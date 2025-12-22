import Foundation
import SwiftData
import Combine

@MainActor
class PlanDashboardViewModel: ObservableObject {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func addDay(plan: WorkoutPlan?, focus: BodyPartFocus, isRestDay: Bool) -> Int {
        guard let plan = plan else { return 0 }
        let nextNumber = ((plan.days ?? []).map { $0.dayNumber }.max() ?? 0) + 1
        let day = WorkoutDay(dayNumber: nextNumber, focus: isRestDay ? .rest : focus, isRestDay: isRestDay)
        day.plan = plan
        if plan.days == nil { plan.days = [] }
        plan.days?.append(day)
        try? modelContext.save()
        return max(0, (plan.days ?? []).count - 1)
    }

    func deleteCurrentDay(plan: WorkoutPlan?, selectedIndex: inout Int) {
        guard let plan = plan else { return }
        let sorted = (plan.days ?? []).sorted(by: { $0.dayNumber < $1.dayNumber })
        guard sorted.indices.contains(selectedIndex) else { return }
        let day = sorted[selectedIndex]
        modelContext.delete(day)
        let remaining = (plan.days ?? []).sorted(by: { $0.dayNumber < $1.dayNumber })
        for (idx, d) in remaining.enumerated() { d.dayNumber = idx + 1 }
        selectedIndex = min(selectedIndex, max(0, remaining.count - 1))
    }

    func startNewCycle(plan: WorkoutPlan?) {
        guard let plan = plan else { return }
        plan.creationDate = Date()
        for day in plan.days ?? [] {
            for ex in day.exercises ?? [] {
                ex.isCompleted = false
                ex.lastCompletedDate = nil
            }
        }
    }

    func resetOnboarding(profiles: [UserProfile], hasOnboarded: inout Bool) {
        for profile in profiles {
            modelContext.delete(profile)
        }
        hasOnboarded = false
    }
}