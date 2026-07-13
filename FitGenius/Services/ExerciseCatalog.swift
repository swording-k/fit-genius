import Foundation
import SwiftData

/// 动作库基础设施：首启种子写入 + 给 AI 生成计划用的目录筛选。
///
/// 设计要点：
/// - 种子数据 `exercises_seed.json` 随包分发（文字数据，符合离线优先），
///   首次启动解析为 `ExerciseTemplate` 写入 SwiftData；用 UserDefaults 标记避免重复写入。
/// - 给 AI 的目录是**本地按用户环境/器械筛选**后的动作名清单，AI 只从中选名，
///   落库时按名匹配回 `ExerciseTemplate`，使 AI 生成的计划和手动从库加的动作**同源**。
enum ExerciseCatalogSeed {
    private static let seededKey = "exerciseCatalogSeeded_v1"

    static var isSeeded: Bool {
        UserDefaults.standard.bool(forKey: seededKey)
    }

    /// 首次启动把 bundled 种子写入 SwiftData。无数据/已写入则直接返回。
    /// 在主线程 ModelContext 上执行，保证动作库 @Query 立即可见。
    @MainActor
    static func ensureSeeded(modelContext: ModelContext) async {
        guard !isSeeded else { return }

        // 升级场景：若已有模板则直接标记完成
        let countDescriptor = FetchDescriptor<ExerciseTemplate>()
        if let existing = try? modelContext.fetch(countDescriptor), !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        guard let url = Bundle.main.url(forResource: "exercises_seed", withExtension: "json") else {
            print("⚠️ [ExerciseCatalogSeed] 未找到 exercises_seed.json，跳过种子写入")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([ExerciseSeedItem].self, from: data)
            for item in items {
                modelContext.insert(item.makeTemplate())
            }
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: seededKey)
            print("✅ [ExerciseCatalogSeed] 已写入 \(items.count) 个动作模板")
        } catch {
            print("❌ [ExerciseCatalogSeed] 写入失败：\(error)")
        }
    }
}

// MARK: - 给 AI 用的目录筛选

extension ExerciseTemplate {
    /// 按用户训练环境（及已选器械）筛选可用动作模板，供 AI 生成计划时参考。
    /// 返回空数组表示库还没建好（首启种子未完成），调用方应优雅跳过注入。
    @MainActor
    static func catalog(for profile: UserProfile, in context: ModelContext) -> [ExerciseTemplate] {
        guard let all = try? context.fetch(FetchDescriptor<ExerciseTemplate>()), !all.isEmpty else {
            return []
        }

        // 1) 先按训练环境收窄
        let envFiltered = all.filter { t in
            switch profile.environment {
            case .gym: return true
            case .home: return t.suitableHome
            case .outdoor: return t.suitableOutdoor
            }
        }

        // 2) 若用户明确选了器械，进一步按器械大类收窄（始终保留徒手类）
        let selected = profile.availableEquipment.map { $0.lowercased() }
        guard !selected.isEmpty else { return envFiltered }

        var allowedCategories = Set(["bodyweight"])
        for equip in selected {
            for (keyword, category) in ExerciseTemplate.chineseEquipmentCategoryMap where equip.contains(keyword) {
                allowedCategories.insert(category)
            }
        }
        guard allowedCategories.count > 1 else { return envFiltered }

        let narrowed = envFiltered.filter { allowedCategories.contains($0.equipmentCategory) }
        return narrowed.isEmpty ? envFiltered : narrowed
    }

    /// 中文器械选择 -> 数据集 equipmentCategory 的映射（用于上述收窄）。
    private static let chineseEquipmentCategoryMap: [String: String] = [
        "哑铃": "dumbbell",
        "杠铃": "barbell",
        "壶铃": "kettlebell",
        "弹力带": "band",
        "绳索": "machine",
        "龙门架": "machine",
        "史密斯机": "machine",
        "卧推架": "machine",
        "深蹲架": "machine",
        "引体": "machine",
        "腿举": "machine",
        "腿弯举": "machine",
        "腿屈伸": "machine",
        "坐姿推胸": "machine",
        "高位下拉": "machine",
        "划船": "machine",
        "蝴蝶机": "machine",
        "跑步机": "machine",
        "瑜伽垫": "bodyweight",
        "泡沫轴": "bodyweight"
    ]
}
