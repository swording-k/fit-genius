import Foundation

/// 动作中文名字典（运行时查表，不进 SwiftData 模型，零迁移风险）。
///
/// 数据集（hasaneyldrm/exercises-dataset）只自带英文动作名，本字典由
/// `scripts/gen_exercise_names_zh.py` 离线用"短语优先 + 词元兜底"的方式
/// 把 1324 条英文名整体翻成中文，落地为 `exercise_names_zh.json`
/// （externalId -> 中文名），随包分发。
///
/// 键为数据集 id（等于 `ExerciseTemplate.externalId`，如 "0001"）。
enum ExerciseNameZh {
    /// externalId -> 中文名。懒加载一次。
    private static let map: [String: String] = load()

    private static func load() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "exercise_names_zh",
                                        withExtension: "json",
                                        subdirectory: "ExerciseLibrary")
            ?? Bundle.main.url(forResource: "exercise_names_zh", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return dict
    }

    /// 按 externalId 取中文名；查不到返回 nil。
    static func chineseName(for externalId: String?) -> String? {
        guard let externalId, let zh = map[externalId], !zh.isEmpty else { return nil }
        return zh
    }

    /// 当前是否偏好中文（系统首选语言以 zh 开头）。
    static var preferChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
    }
}
