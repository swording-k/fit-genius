import Foundation

@main
struct TutorialDiscoveryTests {
    static func clip(_ id: String, templates: [String], url: String?, rights: ExerciseTutorialClip.RightsStatus = .developmentOnly) -> ExerciseTutorialClip {
        ExerciseTutorialClip(id: id, exerciseTemplateIDs: templates, creatorName: "Creator", sourcePlatform: "douyin", sourceURL: URL(string: "https://www.douyin.com/video/123")!, sourceVideoID: "123", sourceTitle: "Demo", clipStartSeconds: 0, clipEndSeconds: 15, playbackURL: url.flatMap(URL.init(string:)), posterURL: nil, cameraView: nil, framingNoteZh: nil, framingNoteEn: nil, rightsStatus: rights)
    }

    static func main() throws {
        let examples = [
            clip("video", templates: ["0334", "0198"], url: "https://example.com/demo.mp4"),
            clip("duplicate", templates: ["0334"], url: "https://example.com/other.mp4"),
            clip("source", templates: ["0031"], url: nil, rights: .externalLinkOnly),
            clip("missing", templates: ["0405"], url: "fitgenius-development:///missing-file.mp4"),
            clip("licensed", templates: ["0025"], url: "https://example.com/licensed.mp4", rights: .licensed),
            clip("invalid", templates: [], url: "https://example.com/invalid.mp4")
        ]
        let debug = ExerciseTutorialCatalog(clips: ExerciseTutorialCatalog.visibleClips(examples, isDebug: true))
        precondition(debug.playableTemplateIDs == Set(["0334", "0198", "0025"]), "Only unique resolvable playback templates belong in the video filter")
        let release = ExerciseTutorialCatalog(clips: ExerciseTutorialCatalog.visibleClips(examples, isDebug: false))
        precondition(release.playableTemplateIDs == Set(["0025"]), "Release counts must follow actual visibility")
        let data = try Data(contentsOf: URL(fileURLWithPath: "cloud-content/exercise-tutorials/catalog-v1.json"))
        let liveFixture = try JSONDecoder().decode(ExerciseTutorialCatalogDocument.self, from: data)
        let current = ExerciseTutorialCatalog(clips: ExerciseTutorialCatalog.visibleClips(liveFixture.clips, isDebug: true))
        precondition(current.playableTemplateIDs.count >= 43)
        precondition(current.playableTemplateIDs.contains("0334"))
        let production = ExerciseTutorialCatalog(clips: ExerciseTutorialCatalog.visibleClips(liveFixture.clips, isDebug: false))
        precondition(production.playableTemplateIDs.isEmpty, "Development assets must not advertise playback in Release")
        precondition(current.playableTemplateIDs.contains("0129"), "New reviewed bench dip must be discoverable")
        let seedData = try Data(contentsOf: URL(fileURLWithPath: "FitGenius/Resources/ExerciseLibrary/exercises_seed.json"))
        let rows = try JSONSerialization.jsonObject(with: seedData) as! [[String: Any]]
        let bench = rows.first { $0["id"] as? String == "0129" }!
        precondition((bench["zh"] as! String).contains("双膝保持弯曲"))
        precondition((bench["en"] as! String).contains("knees bent"))
        print("tutorial-discovery-tests: PASS (\(current.playableTemplateIDs.count) Debug templates)")
    }
}
