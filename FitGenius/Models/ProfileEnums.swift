import Foundation

/// 生理性别（v1.5 新增）。
/// 敏感个人信息，允许用户选择“不愿透露”（nil）。仅在用户主动填写时用于能力基线校准（如女性上肢推力基线更低，自重复合动作优先给退阶）。
enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case female = "女"
    case male = "男"
    case other = "其他"
    case unspecified = "不愿透露"

    var id: String { rawValue }
    var localizedName: String { rawValue }
}

/// 训练经验水平（v1.5 新增），用于能力基线校准。
/// 决定首份计划的难度与是否优先给退阶动作。
enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "新手"
    case intermediate = "进阶"
    case advanced = "资深"

    var id: String { rawValue }
    var localizedName: String { rawValue }
}
