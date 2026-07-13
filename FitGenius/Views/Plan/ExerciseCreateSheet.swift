import SwiftUI
import SwiftData

struct ExerciseCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutDay: WorkoutDay

    @Query private var profiles: [UserProfile]
    @Query(sort: \ExerciseTemplate.nameEn) private var allTemplates: [ExerciseTemplate]

    @State private var searchText = ""
    @State private var selectedTemplate: ExerciseTemplate? = nil
    @State private var name: String = ""
    @State private var sets: String = "3"
    @State private var reps: String = "8-12"
    @State private var weight: String = "0"
    @State private var notes: String = ""

    private var profile: UserProfile? { profiles.first }

    private var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    /// 命中搜索关键词的动作库模板（先按用户训练环境收窄）。
    private var candidates: [ExerciseTemplate] {
        guard !searchText.isEmpty else { return [] }
        let envOk = allTemplates.filter { t in
            guard let env = profile?.environment else { return true }
            switch env {
            case .gym: return true
            case .home: return t.suitableHome
            case .outdoor: return t.suitableOutdoor
            }
        }
        let q = searchText.lowercased()
        return envOk.filter { t in
            let hay = [t.nameEn, t.chineseName ?? "", t.bodyPart, t.target,
                       MuscleName.localized(t.target, preferChinese: preferChinese),
                       t.focusRaw]
                .joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 动作库搜索（优先）
                Section {
                    TextField("exercise_library_search_placeholder".localized, text: $searchText)
                    if !candidates.isEmpty {
                        ForEach(candidates.prefix(20)) { t in
                            Button {
                                selectTemplate(t)
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Color(.secondarySystemBackground)
                                        AnimatedGIFView(urlString: t.gifUrl,
                                                        cacheKey: t.mediaId ?? t.externalId,
                                                        style: .thumbnail)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.displayName)
                                            .foregroundColor(.primary)
                                        Text(MuscleName.localized(t.target, preferChinese: preferChinese))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedTemplate?.id == t.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("search_library".localized)
                }

                // MARK: 已选动作库动作
                if let t = selectedTemplate {
                    Section {
                        HStack {
                            Text(t.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            Button("clear".localized) { clearSelection() }
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("selected_from_library".localized)
                    }
                }

                // MARK: 动作信息（自定义 / 可编辑）
                Section("exercise_info") {
                    TextField("exercise_name", text: $name)
                    HStack {
                        Text("sets")
                        Spacer()
                        TextField("sets", text: $sets)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("reps")
                        Spacer()
                        TextField("e.g_8_12", text: $reps)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("weight_kg")
                        Spacer()
                        TextField("weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                Section("notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("add_exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("add") {
                        addExercise()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func selectTemplate(_ t: ExerciseTemplate) {
        selectedTemplate = t
        name = t.displayName
        notes = t.localizedInstructions(preferChinese: preferChinese)
        reps = "8-12"
        searchText = ""
    }

    private func clearSelection() {
        selectedTemplate = nil
    }

    private func addExercise() {
        let ex = Exercise(
            name: name,
            sets: Int(sets) ?? 3,
            reps: reps,
            weight: Double(weight) ?? 0,
            notes: notes
        )
        // 若从动作库选中，则关联模板（同源：可看 GIF / 标准说明）
        ex.template = selectedTemplate
        ex.workoutDay = workoutDay
        if workoutDay.exercises == nil { workoutDay.exercises = [] }
        ex.orderIndex = (workoutDay.exercises ?? []).count
        workoutDay.exercises?.append(ex)
        modelContext.insert(ex)
        try? modelContext.save()
    }
}
