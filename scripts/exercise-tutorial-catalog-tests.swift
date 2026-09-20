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

        let developmentAssetClip = ExerciseTutorialClip(
            id: "tan-local-development",
            exerciseTemplateIDs: ["0334"],
            creatorName: "谭成义",
            sourcePlatform: "bilibili",
            sourceURL: URL(string: "https://www.bilibili.com/video/BV128bX6eExV/")!,
            sourceVideoID: "BV128bX6eExV",
            sourceTitle: "哑铃侧平举动作讲解",
            clipStartSeconds: 132,
            clipEndSeconds: 151,
            playbackStartSeconds: 0,
            playbackEndSeconds: 19,
            playbackURL: URL(string: "fitgenius-development:///tan-dumbbell-lateral-raise.mp4"),
            posterURL: nil,
            cameraView: "front",
            framingNoteZh: "模仿画面中的正面全身构图",
            framingNoteEn: "Match the front full-body framing",
            rightsStatus: .developmentOnly
        )
        require(
            developmentAssetClip.developmentAssetFileName == "tan-dumbbell-lateral-raise.mp4",
            "a development URL should expose its bundled filename"
        )
        require(
            developmentAssetClip.playbackRange == 0...19,
            "a trimmed playback asset should keep a range separate from the original source timestamps"
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

        requirePlannedExerciseLearningSurface()
        requireUnifiedExerciseLearningEntry()
        requireTutorialAndComparisonSurfaces()
        requireBilingualLearningCopy()

        print("exercise-tutorial-catalog-tests: PASS")
    }

    private static func requirePlannedExerciseLearningSurface() {
        requireSource(
            "FitGenius/Views/Plan/PlannedExerciseDetailView.swift",
            contains: [
            "planned_exercise_prescription",
            "planned_exercise_unmatched_title",
            "ExerciseLearningContent"
            ]
        )
        requireSource(
            "FitGenius/Views/Plan/ExerciseLearningContent.swift",
            contains: [
            "AnimatedGIFView",
            "exercise_detail_instructions",
            "planned_exercise_watch_tutorial",
            "FormAnalysisView"
            ]
        )
    }

    private static func requireUnifiedExerciseLearningEntry() {
        requireSource(
            "FitGenius/Views/Plan/ExerciseLibraryView.swift",
            contains: ["TextField", "exercise_library_search_placeholder"],
            excludes: [".searchable(text:"]
        )
        requireSource(
            "FitGenius/Views/Plan/ExerciseDetailView.swift",
            contains: ["ExerciseLearningContent(template: template)"]
        )
        requireSource(
            "FitGenius/Views/Plan/PlannedExerciseDetailView.swift",
            contains: [
                "ExerciseLearningContent(template: template, formAnalysisExercise: exercise)",
                "planned_exercise_unmatched_title"
            ]
        )
        requireSource(
            "FitGenius/Views/Plan/ExerciseTutorialView.swift",
            excludes: ["let exercise: Exercise", "exercise: Exercise"]
        )
    }

    private static func requireTutorialAndComparisonSurfaces() {
        let requirements: [String: [String]] = [
            "FitGenius/Views/Plan/ExerciseTutorialView.swift": [
                "planned_exercise_source",
                "planned_exercise_compare_video",
                "PhotosPicker"
            ],
            "FitGenius/Views/Plan/ExerciseVideoComparisonView.swift": [
                "ControlledVideoPlayer",
                "comparison_reference",
                "comparison_yours",
                "VideoComparisonTimeline"
            ],
            "FitGenius/Views/Components/ControlledVideoPlayer.swift": [
                "AVPlayerLayer",
                "UIViewRepresentable"
            ]
        ]

        for (path, markers) in requirements {
            guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
                fatalError("FAIL: required video surface is missing at \(path)")
            }
            for marker in markers where !source.contains(marker) {
                fatalError("FAIL: \(path) is missing \(marker)")
            }
        }
    }

    private static func requireBilingualLearningCopy() {
        let keys = [
            "planned_exercise_prescription",
            "planned_exercise_standard_demo",
            "planned_exercise_watch_tutorial",
            "planned_exercise_compare_video",
            "comparison_reference",
            "comparison_yours",
            "comparison_manual_alignment_note"
        ]

        for path in [
            "FitGenius/en.lproj/Localizable.strings",
            "FitGenius/zh-Hans.lproj/Localizable.strings"
        ] {
            guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
                fatalError("FAIL: localization file is missing at \(path)")
            }
            for key in keys where !source.contains("\"\(key)\"") {
                fatalError("FAIL: \(path) is missing \(key)")
            }
        }
    }

    private static func requireSource(
        _ path: String,
        contains requiredMarkers: [String] = [],
        excludes forbiddenMarkers: [String] = []
    ) {
        guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
            fatalError("FAIL: required source is missing at \(path)")
        }
        for marker in requiredMarkers where !source.contains(marker) {
            fatalError("FAIL: \(path) is missing \(marker)")
        }
        for marker in forbiddenMarkers where source.contains(marker) {
            fatalError("FAIL: \(path) must not contain \(marker)")
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError("FAIL: \(message)") }
    }
}
