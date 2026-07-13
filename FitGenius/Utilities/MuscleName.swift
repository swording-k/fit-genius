import Foundation

/// 肌肉名中英映射。
///
/// exercises-dataset 只提供英文名（target / secondary_muscles），而 App 要求
/// 中英文随系统切换。这里集中维护一份映射，详情/列表按 `preferChinese` 展示，
/// 未收录的词原样返回（英文），保证不崩、不空白。
enum MuscleName {
    private static let zhMap: [String: String] = [
        // MARK: target（19）
        "abs": "腹肌",
        "pectorals": "胸大肌",
        "biceps": "肱二头肌",
        "glutes": "臀肌",
        "delts": "三角肌",
        "triceps": "肱三头肌",
        "upper back": "上背",
        "lats": "背阔肌",
        "calves": "小腿肌",
        "quads": "股四头肌",
        "forearms": "前臂",
        "cardiovascular system": "心肺",
        "hamstrings": "股二头肌",
        "spine": "脊柱",
        "traps": "斜方肌",
        "adductors": "内收肌",
        "serratus anterior": "前锯肌",
        "abductors": "外展肌",
        "levator scapulae": "肩胛提肌",
        // MARK: secondary（40）
        "shoulders": "肩部",
        "quadriceps": "股四头肌",
        "core": "核心",
        "chest": "胸部",
        "hip flexors": "髋屈肌",
        "obliques": "腹斜肌",
        "lower back": "下背",
        "rhomboids": "菱形肌",
        "trapezius": "斜方肌",
        "deltoids": "三角肌",
        "rear deltoids": "后束三角肌",
        "brachialis": "肱肌",
        "back": "背部",
        "ankles": "踝关节",
        "feet": "足部",
        "rotator cuff": "肩袖",
        "latissimus dorsi": "背阔肌",
        "ankle stabilizers": "踝稳定肌",
        "soleus": "比目鱼肌",
        "wrists": "腕关节",
        "upper chest": "上胸",
        "wrist flexors": "腕屈肌",
        "wrist extensors": "腕伸肌",
        "abdominals": "腹肌",
        "sternocleidomastoid": "胸锁乳突肌",
        "hands": "手部",
        "groin": "腹股沟",
        "grip muscles": "握力肌",
        "lower abs": "下腹",
        "inner thighs": "大腿内侧",
        "shins": "小腿前侧"
    ]

    /// 按系统语言返回肌肉中文名（中文环境优先中文，否则英文）。
    static func localized(_ english: String, preferChinese: Bool) -> String {
        let key = english.lowercased().trimmingCharacters(in: .whitespaces)
        if preferChinese {
            return zhMap[key] ?? english.capitalized
        }
        return english.capitalized
    }
}
