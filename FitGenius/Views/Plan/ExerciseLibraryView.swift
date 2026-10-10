import SwiftUI
import SwiftData

/// 动作库浏览器。用户可搜索/按部位/按器械筛选，进入详情看演示并加入计划。
///
/// 数据来自随包种子（首启写入 SwiftData 的 `ExerciseTemplate`），离线可用。
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseTemplate.nameEn) private var templates: [ExerciseTemplate]

    @State private var searchText = ""
    @State private var selectedFocus: BodyPartFocus? = nil
    @State private var selectedEquipment: ExerciseEquipmentCategory? = nil
    @State private var tutorialsOnly = false
    @ObservedObject private var tutorials = ExerciseTutorialStore.shared

    private var playableIDs: Set<String> { tutorials.catalog.playableTemplateIDs }

    private var tutorialCount: Int {
        let available = playableIDs
        return templates.filter { available.contains($0.externalId) }.count
    }

    // 部位筛选项：排除“休息”，只保留训练部位
    private let focusOptions: [BodyPartFocus] = [
        .chest, .back, .legs, .shoulders, .arms, .core, .cardio, .fullBody
    ]

    private var filtered: [ExerciseTemplate] {
        let available = playableIDs
        return templates.filter { t in
            if tutorialsOnly && !available.contains(t.externalId) { return false }
            if let selectedFocus, t.focus != selectedFocus { return false }
            if let selectedEquipment, t.equipmentCategory != selectedEquipment.rawValue { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let preferZh = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
                let equipment = (ExerciseEquipmentCategory(rawValue: t.equipmentCategory) ?? .other).localizedName
                let hay = [t.nameEn, t.chineseName ?? "", t.bodyPart, t.target,
                           MuscleName.localized(t.target, preferChinese: preferZh),
                           t.focusRaw, equipment]
                    .joined(separator: " ")
                    .lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        let available = playableIDs
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                if filtered.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(filtered) { template in
                                NavigationLink {
                                    ExerciseDetailView(template: template)
                                } label: {
                                    ExerciseRow(template: template, hasTutorial: available.contains(template.externalId))
                                }
                            }
                        } header: {
                            Text((tutorialsOnly ? "exercise_library_tutorial_results_format" : "exercise_library_count_format").localized(with: filtered.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("exercise_library_title".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await tutorials.refreshIfNeeded() }
    }

    // MARK: - 子视图

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("exercise_library_search_placeholder".localized, text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("clear".localized)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                FilterChip(title: "exercise_library_all_actions".localized,
                           isSelected: !tutorialsOnly) {
                    tutorialsOnly = false
                }
                FilterChip(title: "exercise_library_tutorial_filter_format".localized(with: tutorialCount),
                           systemImage: "play.rectangle.fill",
                           isSelected: tutorialsOnly) {
                    tutorialsOnly.toggle()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "exercise_library_filter_all".localized,
                               isSelected: selectedFocus == nil) {
                        selectedFocus = nil
                    }
                    ForEach(focusOptions) { focus in
                        FilterChip(title: focus.localizedName,
                                   isSelected: selectedFocus == focus) {
                            selectedFocus = (selectedFocus == focus) ? nil : focus
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "exercise_library_filter_all".localized,
                               systemImage: "square.grid.2x2",
                               isSelected: selectedEquipment == nil) {
                        selectedEquipment = nil
                    }
                    ForEach(ExerciseEquipmentCategory.allCases) { equip in
                        FilterChip(title: equip.localizedName,
                                   systemImage: equip.systemImage,
                                   isSelected: selectedEquipment == equip) {
                            selectedEquipment = (selectedEquipment == equip) ? nil : equip
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text((tutorialsOnly ? "exercise_library_tutorial_empty" : "exercise_library_empty").localized)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if tutorialsOnly {
                Button("exercise_library_show_all".localized) {
                    tutorialsOnly = false
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 列表行

private struct ExerciseRow: View {
    let template: ExerciseTemplate
    let hasTutorial: Bool

    private var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }

    var body: some View {
        HStack(spacing: 12) {
            // 动图缩略图：直接展示动作演示 GIF，用户不进详情也能一眼看懂动作。
            ZStack {
                Color(.secondarySystemBackground)
                AnimatedGIFView(urlString: template.gifUrl,
                                cacheKey: template.mediaId ?? template.externalId,
                                style: .thumbnail)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(template.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(template.focus.localizedName)
                    Text("·")
                    Text(template.localizedTarget(preferChinese: preferChinese))
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                if hasTutorial {
                    Label("exercise_library_tutorial_badge".localized, systemImage: "play.rectangle.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 筛选 Chip

private struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
