import Foundation
import SwiftData

@MainActor
enum CurrentWorkoutPlanStore {
    static func resolve(
        profiles: [UserProfile],
        plans: [WorkoutPlan]
    ) -> WorkoutPlan? {
        var candidates = plans
        for profile in profiles {
            if let linked = profile.workoutPlan,
               !candidates.contains(where: { $0 === linked }) {
                candidates.append(linked)
            }
        }

        let indexed = candidates.enumerated().map { index, plan in
            CurrentWorkoutPlanCandidate(
                id: index,
                creationDate: plan.creationDate,
                isLinkedToProfile: profiles.contains { $0.workoutPlan === plan }
            )
        }
        guard let index = CurrentWorkoutPlanPolicy.selectID(from: indexed) else {
            return nil
        }
        return candidates[index]
    }

    @discardableResult
    static func ensureCurrentPlan(in context: ModelContext) throws -> WorkoutPlan {
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        if let existing = resolve(profiles: profiles, plans: plans) {
            return existing
        }

        let draft = WorkoutPlan()
        context.insert(draft)
        try context.save()
        return draft
    }
}
