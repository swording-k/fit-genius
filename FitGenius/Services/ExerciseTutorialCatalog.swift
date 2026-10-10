import Foundation

struct ExerciseTutorialCatalog {
    static let supportedSchemaVersion = 1

    let clips: [ExerciseTutorialClip]

    init(clips: [ExerciseTutorialClip]) {
        self.clips = clips
            .filter { $0.validationError == nil }
            .sorted {
                if $0.clipStartSeconds == $1.clipStartSeconds { return $0.id < $1.id }
                return $0.clipStartSeconds < $1.clipStartSeconds
            }
    }

    func clips(for exerciseTemplateID: String) -> [ExerciseTutorialClip] {
        clips.filter { $0.exerciseTemplateIDs.contains(exerciseTemplateID) }
    }

    /// Uses the same build-filtered catalog as details; source links are not videos.
    var playableTemplateIDs: Set<String> {
        Set(clips.filter {
            $0.rightsStatus != .externalLinkOnly && $0.resolvedPlaybackURL() != nil
        }.flatMap(\.exerciseTemplateIDs))
    }

    static func visibleClips(_ clips: [ExerciseTutorialClip], isDebug: Bool) -> [ExerciseTutorialClip] {
        clips.filter { clip in
            switch clip.rightsStatus {
            case .developmentOnly:
                return isDebug
            case .licensed, .externalLinkOnly:
                return true
            }
        }
    }

    static func loadBundled(bundle: Bundle = .main, isDebug: Bool = Self.currentBuildIsDebug) -> ExerciseTutorialCatalog {
        guard let url = bundle.url(
            forResource: "tutorial_clips",
            withExtension: "json",
            subdirectory: "ExerciseTutorials"
        ) ?? bundle.url(forResource: "tutorial_clips", withExtension: "json"),
        let data = try? Data(contentsOf: url),
        let document = try? JSONDecoder().decode(ExerciseTutorialCatalogDocument.self, from: data),
        document.schemaVersion == supportedSchemaVersion else {
            return ExerciseTutorialCatalog(clips: [])
        }

        return ExerciseTutorialCatalog(clips: visibleClips(document.clips, isDebug: isDebug))
    }

    private static var currentBuildIsDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
