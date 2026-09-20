import Foundation

struct CurrentWorkoutPlanCandidate<ID: Hashable> {
    let id: ID
    let creationDate: Date
    let isLinkedToProfile: Bool
}

enum CurrentWorkoutPlanPolicy {
    static func selectID<ID: Hashable>(
        from candidates: [CurrentWorkoutPlanCandidate<ID>]
    ) -> ID? {
        let linked = candidates.filter(\.isLinkedToProfile)
        return (linked.isEmpty ? candidates : linked)
            .max { $0.creationDate < $1.creationDate }?
            .id
    }
}
