import Foundation

struct AppLanguagePolicy {
    let preferredLanguageIdentifier: String

    static var current: AppLanguagePolicy {
        AppLanguagePolicy(
            preferredLanguageIdentifier: Locale.preferredLanguages.first ?? "en-US"
        )
    }

    var prefersSimplifiedChinese: Bool {
        let identifier = preferredLanguageIdentifier.lowercased()
        return identifier.hasPrefix("zh-hans") || identifier.hasPrefix("zh-cn")
    }

    var speechLocaleIdentifier: String {
        prefersSimplifiedChinese ? "zh-CN" : "en-US"
    }

    var responseLanguageInstruction: String {
        prefersSimplifiedChinese
            ? "请使用简体中文回复。"
            : "Respond in English."
    }

    var planContentInstruction: String {
        if prefersSimplifiedChinese {
            return "计划名称、动作名称、备注等用户可见内容使用简体中文；focus 必须使用以下内部枚举值之一：胸部、背部、腿部、肩部、手臂、核心、全身、有氧、休息。"
        }
        return "Write user-visible content such as the plan name, exercise names, and notes in English. The focus field is an internal contract and must still be exactly one of: 胸部、背部、腿部、肩部、手臂、核心、全身、有氧、休息."
    }
}
