import Foundation

struct FormCoachEnrichmentResult: Codable, Hashable {
    let coachNote: String?
    let selectedFrameIndexes: [Int]
    let annotations: [FormCoachAnnotation]
    let cues: [FormCoachCue]

    private enum CodingKeys: String, CodingKey {
        case coachNote = "coach_note"
        case selectedFrameIndexes = "selected_frame_indexes"
        case annotations
        case cues
    }
}

struct FormCoachAnnotation: Codable, Hashable {
    let imageIndex: Int
    let label: String
    let type: String
    let joints: [String]
    let severity: Int?

    private enum CodingKeys: String, CodingKey {
        case imageIndex = "image_index"
        case label
        case type
        case joints
        case severity
    }

    var resolvedJoints: [JointName] {
        joints.compactMap(JointName.init(rawValue:))
    }
}

struct PoseFrameBundle: Hashable {
    let frame: PoseFrame
    let skeletonImageData: Data
}

struct FormCoachEnrichmentArtifact: Hashable {
    let result: FormCoachEnrichmentResult
    let annotatedImageData: [Data]

    var cues: [FormCoachCue] { result.cues }
    var coachNote: String? { result.coachNote }
}

enum FormCoachEnrichmentError: Error {
    case notEnoughFrames
    case noUsableFrame
}
