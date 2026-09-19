import Foundation

@main
struct ExerciseTutorialCatalogTests {
    static func main() {
        let valid = ExerciseTutorialClip(
            id: "tan-bench-001",
            exerciseTemplateIDs: ["0025"],
            creatorName: "谭成义",
            sourcePlatform: "bilibili",
            sourceURL: URL(string: "https://www.bilibili.com/video/BVexample")!,
            sourceVideoID: "BVexample",
            sourceTitle: "卧推教学",
            clipStartSeconds: 12,
            clipEndSeconds: 24,
            playbackURL: nil,
            posterURL: nil,
            cameraView: "front-oblique",
            framingNoteZh: "保持全身入镜",
            framingNoteEn: "Keep the full body in frame",
            rightsStatus: .developmentOnly
        )

        require(valid.validationError == nil, "a valid clip should pass validation")

        let invalidRange = ExerciseTutorialClip(
            id: "bad-range",
            exerciseTemplateIDs: ["0025"],
            creatorName: "谭成义",
            sourcePlatform: "bilibili",
            sourceURL: URL(string: "https://www.bilibili.com/video/BVexample")!,
            sourceVideoID: "BVexample",
            sourceTitle: "卧推教学",
            clipStartSeconds: 24,
            clipEndSeconds: 12,
            playbackURL: nil,
            posterURL: nil,
            cameraView: nil,
            framingNoteZh: nil,
            framingNoteEn: nil,
            rightsStatus: .externalLinkOnly
        )
        require(invalidRange.validationError == "invalid clip range", "an inverted range must be rejected")

        let catalog = ExerciseTutorialCatalog(clips: [valid])
        require(catalog.clips(for: "0025").map(\.id) == ["tan-bench-001"], "template lookup should return its clip")
        require(catalog.clips(for: "missing").isEmpty, "an unmapped template should have no clips")
        require(
            ExerciseTutorialCatalog.visibleClips([valid], isDebug: false).isEmpty,
            "release filtering must hide development-only media"
        )
        require(
            ExerciseTutorialCatalog.visibleClips([valid], isDebug: true).map(\.id) == ["tan-bench-001"],
            "debug filtering should retain development-only media"
        )

        let candidates = [
            ExerciseTemplateResolver.Candidate(
                id: "bench",
                names: ["barbell bench press", "杠铃卧推"]
            ),
            ExerciseTemplateResolver.Candidate(
                id: "incline",
                names: ["incline bench press", "上斜卧推"]
            )
        ]
        require(
            ExerciseTemplateResolver.resolve("Barbell Bench-Press", in: candidates) == "bench",
            "punctuation and case should not prevent an exact normalized match"
        )
        require(
            ExerciseTemplateResolver.resolve("卧推", in: candidates) == "bench",
            "a reviewed Chinese alias should resolve to the standard movement"
        )
        require(
            ExerciseTemplateResolver.resolve("bench press", in: candidates) == nil,
            "an ambiguous partial match must be rejected"
        )

        print("exercise-tutorial-catalog-tests: PASS")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
