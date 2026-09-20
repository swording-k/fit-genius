import Foundation

struct PlanEditSnapshot {
    struct Day {
        let dayNumber: Int
        let isRestDay: Bool
        let exerciseNames: [String]
    }

    let days: [Day]
}

struct PlanEditRequest {
    enum Kind {
        case update
        case add
        case remove
    }

    let kind: Kind
    let dayNumber: Int?
    let targetName: String?
    let replacementName: String?
    let sets: Int?
    let reps: String?
    let weight: Double?
}

struct PlanEditValidationResult {
    let errors: [String]
    var isValid: Bool { errors.isEmpty }
}

enum PlanEditValidationPolicy {
    static func validateReplacement(
        _ plan: PlanEditSnapshot
    ) -> PlanEditValidationResult {
        var errors: [String] = []
        let ordered = plan.days.sorted { $0.dayNumber < $1.dayNumber }
        let expected = Array(1...ordered.count)
        if ordered.map(\.dayNumber) != expected {
            errors.append("plan_edit_error_days_not_continuous")
        }
        if !ordered.contains(where: { !$0.isRestDay }) {
            errors.append("plan_edit_error_no_training_day")
        }
        for day in ordered {
            if day.isRestDay && !day.exerciseNames.isEmpty {
                errors.append("plan_edit_error_rest_day")
            }
            let normalized = day.exerciseNames.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            if normalized.contains(where: \.isEmpty) {
                errors.append("plan_edit_error_name_empty")
            }
            if Set(normalized).count != normalized.count {
                errors.append("plan_edit_error_duplicate_exercise")
            }
        }
        return PlanEditValidationResult(errors: errors)
    }

    static func validate(
        _ request: PlanEditRequest,
        against plan: PlanEditSnapshot
    ) -> PlanEditValidationResult {
        var errors: [String] = []

        guard let dayNumber = request.dayNumber,
              let day = plan.days.first(where: { $0.dayNumber == dayNumber }) else {
            return PlanEditValidationResult(errors: ["plan_edit_error_day_missing"])
        }

        if let sets = request.sets, !(1...20).contains(sets) {
            errors.append("plan_edit_error_sets_range")
        }
        if let weight = request.weight, weight < 0 {
            errors.append("plan_edit_error_weight_negative")
        }
        if let reps = request.reps,
           reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("plan_edit_error_reps_empty")
        }

        switch request.kind {
        case .add:
            if day.isRestDay {
                errors.append("plan_edit_error_rest_day")
            }
            if request.replacementName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                errors.append("plan_edit_error_name_empty")
            }
        case .update:
            validateUniqueTarget(request.targetName, in: day, errors: &errors)
            if request.replacementName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                errors.append("plan_edit_error_name_empty")
            }
        case .remove:
            validateUniqueTarget(request.targetName, in: day, errors: &errors)
        }

        return PlanEditValidationResult(errors: errors)
    }

    private static func validateUniqueTarget(
        _ targetName: String?,
        in day: PlanEditSnapshot.Day,
        errors: inout [String]
    ) {
        guard let target = targetName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty else {
            errors.append("plan_edit_error_target_missing")
            return
        }
        let matches = day.exerciseNames.filter {
            $0.caseInsensitiveCompare(target) == .orderedSame
        }
        if matches.count != 1 {
            errors.append(matches.isEmpty
                ? "plan_edit_error_target_missing"
                : "plan_edit_error_target_ambiguous")
        }
    }
}
