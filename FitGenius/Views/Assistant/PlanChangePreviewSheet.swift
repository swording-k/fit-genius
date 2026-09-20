import SwiftUI

struct PlanChangePreviewSheet: View {
    let command: AIActionCommand
    let validationErrors: [String]
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("plan_edit_preview_detail", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }

                Section("plan_edit_preview_changes") {
                    ForEach(Array(command.actions.enumerated()), id: \.offset) { _, action in
                        PlanEditPreviewRow(commandType: command.type, action: action)
                    }
                }

                if !validationErrors.isEmpty {
                    Section("plan_edit_preview_cannot_apply") {
                        ForEach(validationErrors, id: \.self) { key in
                            Label(key.localized, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("plan_edit_preview_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("plan_edit_apply", action: onApply)
                        .disabled(!validationErrors.isEmpty)
                }
            }
        }
    }
}

struct PlanReplacementPreviewSheet: View {
    let currentPlan: WorkoutPlan
    let replacement: WorkoutPlan
    let validationErrors: [String]
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("plan_replacement_summary") {
                    LabeledContent("plan_replacement_current") {
                        Text("\(currentPlan.name) · \((currentPlan.days ?? []).count) \("days".localized)")
                    }
                    LabeledContent("plan_replacement_candidate") {
                        Text("\(replacement.name) · \((replacement.days ?? []).count) \("days".localized)")
                    }
                }

                Section("plan_replacement_candidate_days") {
                    ForEach((replacement.days ?? []).sorted { $0.dayNumber < $1.dayNumber }) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(
                                "plan_edit_day".localized(with: day.dayNumber) + " · " + day.focus.localizedName,
                                systemImage: day.isRestDay ? "bed.double.fill" : "figure.strengthtraining.traditional"
                            )
                            .font(.body.weight(.semibold))
                            if day.isRestDay {
                                Text("rest")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach((day.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }) { exercise in
                                    Text("• \(exercise.localizedDisplayName) · \(exercise.sets) × \(exercise.reps)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }

                if !validationErrors.isEmpty {
                    Section("plan_edit_preview_cannot_apply") {
                        ForEach(validationErrors, id: \.self) { key in
                            Label(key.localized, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("plan_replacement_preview_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("plan_replacement_apply", action: onApply)
                        .disabled(!validationErrors.isEmpty)
                }
            }
        }
    }
}

private struct PlanEditPreviewRow: View {
    let commandType: String
    let action: AIActionCommand.Action

    private var icon: String {
        switch commandType {
        case "add_exercise": return "plus.circle.fill"
        case "remove_exercise": return "minus.circle.fill"
        default: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    private var tint: Color {
        switch commandType {
        case "add_exercise": return .green
        case "remove_exercise": return .red
        default: return .blue
        }
    }

    private var title: String {
        let day = action.day.map { "plan_edit_day".localized(with: $0) } ?? ""
        switch commandType {
        case "add_exercise":
            return "\(day) · \(action.newExercise ?? action.exerciseName ?? "—")"
        case "remove_exercise":
            return "\(day) · \(action.exerciseName ?? action.oldExercise ?? "—")"
        default:
            return "\(day) · \(action.oldExercise ?? "—") → \(action.newExercise ?? "—")"
        }
    }

    private var prescription: String? {
        let parts = [
            action.sets.map { "plan_edit_sets".localized(with: $0) },
            action.reps.map { "plan_edit_reps".localized(with: $0) },
            action.weight.map { "plan_edit_weight".localized(with: $0) }
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.semibold))
                if let prescription {
                    Text(prescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let reason = action.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
