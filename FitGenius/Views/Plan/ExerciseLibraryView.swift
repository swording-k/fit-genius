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

    // 部位筛选项：排除“休息”，只保留训练部位
    private let focusOptions: [BodyPartFocus] = [
        .chest, .back, .legs, .shoulders, .arms, .core, .cardio, .fullBody
    ]

    private var filtered: [ExerciseTemplate] {
        templates.filter { t in
            if let selectedFocus, t.focus != selectedFocus { return false }
            if let selectedEquipment, t.equipmentCategory != selectedEquipment.rawValue { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let preferZh = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
                let hay = [t.nameEn, t.chineseName ?? "", t.bodyPart, t.target,
                           MuscleName.localized(t.target, preferChinese: preferZh),
                           t.focusRaw]
                    .joined(separator: " ")
                    .lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
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
                                    ExerciseRow(template: template)
                                }
                            }
                        } header: {
                            Text("exercise_library_count_format".localized(with: filtered.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("exercise_library_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "exercise_library_search_placeholder".localized)
        }
    }

    // MARK: - 子视图

    private var filterBar: some View {
        VStack(spacing: 8) {
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
            Text("exercise_library_empty".localized)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 列表行

private struct ExerciseRow: View {
    let template: ExerciseTemplate

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
