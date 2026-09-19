import Foundation

/// A reviewed segment from a creator's source video that teaches one or more
/// exercise-library movements. Video binaries are deliberately kept outside
/// SwiftData and Git; this value only stores traceable metadata.
struct ExerciseTutorialClip: Codable, Identifiable, Hashable {
    enum RightsStatus: String, Codable {
        case developmentOnly
        case licensed
        case externalLinkOnly
    }

    let id: String
    let exerciseTemplateIDs: [String]
    let creatorName: String
    let sourcePlatform: String
    let sourceURL: URL
    let sourceVideoID: String
    let sourceTitle: String
    let clipStartSeconds: Double
    let clipEndSeconds: Double
    let playbackURL: URL?
    let posterURL: URL?
    let cameraView: String?
    let framingNoteZh: String?
    let framingNoteEn: String?
    let rightsStatus: RightsStatus

    var validationError: String? {
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "missing id"
        }
        if exerciseTemplateIDs.isEmpty {
            return "missing exercise template"
        }
        if creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "missing creator"
        }
        if sourceVideoID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "missing source video id"
        }
        if clipStartSeconds < 0 || clipEndSeconds <= clipStartSeconds {
            return "invalid clip range"
        }
        if rightsStatus == .licensed && playbackURL == nil {
            return "licensed clip missing playback url"
        }
        return nil
    }

    func localizedFramingNote(preferChinese: Bool) -> String? {
        if preferChinese {
            return framingNoteZh?.nilIfEmpty ?? framingNoteEn?.nilIfEmpty
        }
        return framingNoteEn?.nilIfEmpty ?? framingNoteZh?.nilIfEmpty
    }
}

struct ExerciseTutorialCatalogDocument: Codable {
    let schemaVersion: Int
    let clips: [ExerciseTutorialClip]
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
