import SwiftUI
import SwiftData

/// 动作详情：演示 GIF（按需加载）+ 说明 + 目标肌肉 + 加入计划。
struct ExerciseDetailView: View {
    let template: ExerciseTemplate

    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false

    private var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                demoSection
                metaSection
                instructionsSection
                if let attribution = template.attribution, !attribution.isEmpty {
                    Text("exercise_detail_attribution_format".localized(with: attribution))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(template.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                showAddSheet = true
            } label: {
                Text("exercise_add_to_plan".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAddSheet) {
            AddExerciseToPlanSheet(template: template)
        }
        // 进入详情时隐藏顶部全局"模式切换"浮层，避免与返回按钮重合。
        .hidesGlobalModeToggle()
    }

    // MARK: - 演示

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("exercise_detail_demo".localized)
                .font(.headline)
            AnimatedGIFView(urlString: template.gifUrl, cacheKey: template.mediaId ?? template.externalId)
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 元信息

    private var metaSection: some View {
        VStack(spacing: 10) {
            metaRow(label: "exercise_detail_body_part".localized, value: template.focus.localizedName)
            metaRow(label: "exercise_detail_equipment".localized,
                    value: (ExerciseEquipmentCategory(rawValue: template.equipmentCategory) ?? .other).localizedName)
            metaRow(label: "exercise_detail_target".localized,
                    value: template.localizedTarget(preferChinese: preferChinese))
            if !template.secondaryMuscles.isEmpty {
                metaRow(label: "exercise_detail_secondary".localized,
                        value: template.localizedSecondaryMuscles(preferChinese: preferChinese).joined(separator: ", "))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - 说明

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("exercise_detail_instructions".localized)
                .font(.headline)
            Text(template.localizedInstructions(preferChinese: preferChinese))
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 加入计划 Sheet

/// 把动作库模板作为一个新的 `Exercise` 加入当前计划的某个训练日。
/// 生成的 Exercise 会用 `template` 关系指回来源模板（同源）。
private struct AddExerciseToPlanSheet: View {
    let template: ExerciseTemplate

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var selectedDay: WorkoutDay?
    @State private var sets: Int = 3
    @State private var reps: String = "8-12"
    @State private var weight: Double = 0
    @State private var showSuccess = false

    /// 用户当前计划（与计划页 `profiles.first?.workoutPlan` 一致），
    /// 避免 `plans.first` 盲选到错误计划导致"加进去了却看不到"。
    private var plan: WorkoutPlan? { profiles.first?.workoutPlan }

    private var days: [WorkoutDay] {
        (plan?.days ?? [])
            .filter { !$0.isRestDay }
            .sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        NavigationStack {
            Group {
                if plan == nil || days.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("exercise_add_to_plan_no_plan".localized)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form {
                        Section("exercise_add_to_plan_select_day".localized) {
                            Picker("exercise_add_to_plan_select_day".localized, selection: $selectedDay) {
                                ForEach(days) { day in
                                    Text("\("day_number_format".localized(with: day.dayNumber)) · \(day.focus.localizedName)")
                                        .tag(day as WorkoutDay?)
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }

                        Section {
                            Stepper(value: $sets, in: 1...10) {
                                HStack {
                                    Text("exercise_add_to_plan_sets".localized)
                                    Spacer()
                                    Text("\(sets)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            HStack {
                                Text("exercise_add_to_plan_reps".localized)
                                Spacer()
                                TextField("8-12", text: $reps)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                            HStack {
                                Text("exercise_add_to_plan_weight".localized)
                                Spacer()
                                TextField("0", value: $weight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                        }
                    }
                }
            }
            .navigationTitle(template.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("exercise_add_to_plan_confirm".localized) {
                        addToPlan()
                    }
                    .disabled(selectedDay == nil)
                }
            }
            .onAppear {
                if selectedDay == nil { selectedDay = days.first }
            }
            .alert("exercise_add_to_plan_success".localized, isPresented: $showSuccess) {
                Button("ok".localized) { dismiss() }
            }
        }
    }

    private func addToPlan() {
        guard let day = selectedDay else { return }
        let exercise = Exercise(
            name: template.displayName,
            sets: sets,
            reps: reps,
            weight: weight,
            notes: template.localizedInstructions(preferChinese: Locale.preferredLanguages.first?.hasPrefix("zh") ?? false)
        )
        exercise.template = template
        exercise.workoutDay = day
        let existing = day.exercises ?? []
        exercise.orderIndex = (existing.map(\.orderIndex).max() ?? -1) + 1
        if day.exercises == nil { day.exercises = [] }
        day.exercises?.append(exercise)
        modelContext.insert(exercise)
        try? modelContext.save()
        showSuccess = true
    }
}
