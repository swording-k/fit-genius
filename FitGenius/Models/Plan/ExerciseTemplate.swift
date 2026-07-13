import Foundation
import SwiftData

/// 动作模板（动作库目录层）。
///
/// 数据来源：hasaneyldrm/exercises-dataset（说明文本 MIT 许可；GIF 媒体版权
/// © Gym visual，因此媒体**不打包**，详情页按需从 `gifUrl` 加载）。
///
/// 这是"参考目录"，与用户计划里的 `Exercise` 实例区分：用户从库里选一个
/// 模板，会据此**生成**一个 `Exercise`（带名字、说明写进 notes），并用
/// `Exercise.template` 关系指回来源模板，从而打通 GIF 演示与姿态对照。
@Model
final class ExerciseTemplate {
    /// 数据集内的唯一 id（如 "0001"），用于去重与稳定标识。
    @Attribute(.unique) var externalId: String
    var nameEn: String
    /// 数据集原始部位（英文，如 "waist"），保留用于调试/检索。
    var bodyPart: String
    /// 映射后的部位枚举原始值（`BodyPartFocus.rawValue`，中文），用于和训练日对齐。
    var focusRaw: String
    /// 器械原始名（英文，如 "dumbbell"）。
    var equipment: String
    /// UI 归类：bodyweight / dumbbell / barbell / machine / kettlebell / band / other。
    var equipmentCategory: String
    /// 主要目标肌肉（英文）。
    var target: String
    /// 协同肌群（英文）。
    var secondaryMuscles: [String]
    /// 中文分步说明（数据集自带，100% 覆盖）。
    var instructionsZh: String
    /// 英文分步说明。
    var instructionsEn: String
    /// 媒体 id（拼 CDN 用；媒体不打包）。
    var mediaId: String?
    /// GIF 演示地址（按需加载 + 沙盒缓存；不打包）。
    var gifUrl: String?
    /// 媒体版权署名（详情页展示，满足 license 要求）。
    var attribution: String?
    /// 环境适配，用于按 profile.environment 过滤。
    var suitableGym: Bool
    var suitableHome: Bool
    var suitableOutdoor: Bool

    init(
        externalId: String,
        nameEn: String,
        bodyPart: String,
        focusRaw: String,
        equipment: String,
        equipmentCategory: String,
        target: String,
        secondaryMuscles: [String],
        instructionsZh: String,
        instructionsEn: String,
        mediaId: String?,
        gifUrl: String?,
        attribution: String?,
        suitableGym: Bool,
        suitableHome: Bool,
        suitableOutdoor: Bool
    ) {
        self.externalId = externalId
        self.nameEn = nameEn
        self.bodyPart = bodyPart
        self.focusRaw = focusRaw
        self.equipment = equipment
        self.equipmentCategory = equipmentCategory
        self.target = target
        self.secondaryMuscles = secondaryMuscles
        self.instructionsZh = instructionsZh
        self.instructionsEn = instructionsEn
        self.mediaId = mediaId
        self.gifUrl = gifUrl
        self.attribution = attribution
        self.suitableGym = suitableGym
        self.suitableHome = suitableHome
        self.suitableOutdoor = suitableOutdoor
    }

    // MARK: - 便捷派生属性

    /// 映射后的部位枚举（解析失败回退 .fullBody）。
    var focus: BodyPartFocus {
        BodyPartFocus(rawValue: focusRaw) ?? .fullBody
    }

    /// 按当前语言选说明（中文环境优先中文，否则英文；缺失互为兜底）。
    func localizedInstructions(preferChinese: Bool) -> String {
        if preferChinese {
            return instructionsZh.isEmpty ? instructionsEn : instructionsZh
        }
        return instructionsEn.isEmpty ? instructionsZh : instructionsEn
    }

    /// 展示名。中文环境优先用离线字典（`ExerciseNameZh`，按 externalId 查表）翻出的
    /// 中文名；查不到或英文环境则回退英文原名 `nameEn`。字典随包、运行时查表，
    /// 不改本模型字段，故无 SwiftData 迁移风险。
    var displayName: String {
        if ExerciseNameZh.preferChinese, let zh = ExerciseNameZh.chineseName(for: externalId) {
            return zh
        }
        return nameEn
    }

    /// 中文名（若字典有），供搜索命中中文关键词用；无则 nil。
    var chineseName: String? { ExerciseNameZh.chineseName(for: externalId) }

    /// 目标肌肉（按系统语言）。数据集仅英文，经 `MuscleName` 映射为中文。
    func localizedTarget(preferChinese: Bool) -> String {
        MuscleName.localized(target, preferChinese: preferChinese)
    }

    /// 协同肌群（按系统语言）。
    func localizedSecondaryMuscles(preferChinese: Bool) -> [String] {
        secondaryMuscles.map { MuscleName.localized($0, preferChinese: preferChinese) }
    }
}

// MARK: - 器械 UI 分类

/// 动作库筛选用的器械大类。`rawValue` 对应 seed 里的 equipmentCategory。
enum ExerciseEquipmentCategory: String, CaseIterable, Identifiable {
    case bodyweight
    case dumbbell
    case barbell
    case machine
    case kettlebell
    case band
    case other

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .bodyweight: return "exercise_equipment_bodyweight".localized
        case .dumbbell: return "exercise_equipment_dumbbell".localized
        case .barbell: return "exercise_equipment_barbell".localized
        case .machine: return "exercise_equipment_machine".localized
        case .kettlebell: return "exercise_equipment_kettlebell".localized
        case .band: return "exercise_equipment_band".localized
        case .other: return "exercise_equipment_other".localized
        }
    }

    var systemImage: String {
        switch self {
        case .bodyweight: return "figure.strengthtraining.functional"
        case .dumbbell: return "dumbbell"
        case .barbell: return "figure.strengthtraining.traditional"
        case .machine: return "gearshape.2"
        case .kettlebell: return "figure.core.training"
        case .band: return "waveform.path"
        case .other: return "circle.grid.cross"
        }
    }
}

// MARK: - Seed 解码

/// 与 exercises_seed.json 一一对应的解码结构。
struct ExerciseSeedItem: Decodable {
    let id: String
    let name: String
    let bodyPart: String?
    let focusRaw: String?
    let equipment: String?
    let equipmentCategory: String?
    let target: String?
    let secondaryMuscles: [String]?
    let zh: String?
    let en: String?
    let mediaId: String?
    let gifUrl: String?
    let attribution: String?
    let suitableGym: Bool?
    let suitableHome: Bool?
    let suitableOutdoor: Bool?

    func makeTemplate() -> ExerciseTemplate {
        ExerciseTemplate(
            externalId: id,
            nameEn: name,
            bodyPart: bodyPart ?? "",
            focusRaw: focusRaw ?? "全身",
            equipment: equipment ?? "",
            equipmentCategory: equipmentCategory ?? "other",
            target: target ?? "",
            secondaryMuscles: secondaryMuscles ?? [],
            instructionsZh: zh ?? "",
            instructionsEn: en ?? "",
            mediaId: mediaId,
            gifUrl: gifUrl,
            attribution: attribution,
            suitableGym: suitableGym ?? true,
            suitableHome: suitableHome ?? true,
            suitableOutdoor: suitableOutdoor ?? false
        )
    }
}
