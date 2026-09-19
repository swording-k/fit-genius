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
    var playbackStartSeconds: Double? = nil
    var playbackEndSeconds: Double? = nil
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
        if (playbackStartSeconds == nil) != (playbackEndSeconds == nil) {
            return "incomplete playback range"
        }
        if let playbackStartSeconds,
           let playbackEndSeconds,
           (playbackStartSeconds < 0 || playbackEndSeconds <= playbackStartSeconds) {
            return "invalid playback range"
        }
        if rightsStatus == .licensed && playbackURL == nil {
            return "licensed clip missing playback url"
        }
        return nil
    }

    var playbackRange: ClosedRange<Double> {
        let start = playbackStartSeconds ?? clipStartSeconds
        let end = playbackEndSeconds ?? clipEndSeconds
        return start...end
    }

    /// DEBUG catalog entries can point at an ignored, local-only bundle asset.
    /// Production entries use a normal HTTPS CloudBase/CDN URL instead.
    var developmentAssetFileName: String? {
        guard playbackURL?.scheme == "fitgenius-development" else { return nil }
        let fileName = playbackURL?.lastPathComponent ?? ""
        return fileName.isEmpty ? nil : fileName
    }

    func resolvedPlaybackURL(bundle: Bundle = .main) -> URL? {
        guard let developmentAssetFileName else { return playbackURL }
        let fileURL = URL(fileURLWithPath: developmentAssetFileName)
        let name = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension
        return bundle.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "ExerciseTutorials/DevelopmentMedia"
        ) ?? bundle.url(forResource: name, withExtension: ext)
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
