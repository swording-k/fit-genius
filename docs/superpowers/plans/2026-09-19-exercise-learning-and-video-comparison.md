# Exercise Learning and Video Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every planned strength exercise open a useful learning page, optionally show an approved Tan Sir tutorial clip, and let the user compare that reference with a locally selected video side by side.

**Architecture:** Keep `Exercise` and `ExerciseTemplate` as the training and reference sources of truth. Add a separate Codable tutorial catalog keyed by `ExerciseTemplate.externalId`, then build planned-exercise detail, tutorial playback, and comparison views on top of it. Keep synchronization math in a Foundation-only policy so it is testable without AVFoundation, and keep tutorial binaries out of Git and SwiftData.

**Tech Stack:** SwiftUI, SwiftData, PhotosUI, AVKit/AVFoundation, bundled JSON with future CloudBase Storage override, Swift script regression tests, Xcode simulator build.

---

## File Map

- Create `FitGenius/Models/Plan/ExerciseTutorialClip.swift`: Codable tutorial metadata, rights status, validation.
- Create `FitGenius/Models/Plan/VideoComparisonTimeline.swift`: pure comparison-time calculations.
- Create `FitGenius/Services/ExerciseTutorialCatalog.swift`: bundled catalog loading, release filtering, template lookup.
- Create `FitGenius/Services/ExerciseTemplateResolver.swift`: safe exact/alias matching for old or manually created plan exercises.
- Create `FitGenius/Resources/ExerciseTutorials/tutorial_clips.json`: reviewed metadata only; no video binary.
- Create `FitGenius/Views/Plan/PlannedExerciseDetailView.swift`: plan prescription plus action-library teaching content.
- Create `FitGenius/Views/Plan/ExerciseTutorialView.swift`: reference clip, source attribution, framing cue, user-video picker.
- Create `FitGenius/Views/Plan/ExerciseVideoComparisonView.swift`: dual player, offsets, common seek/rate controls.
- Create `FitGenius/Views/Components/ControlledVideoPlayer.swift`: SwiftUI wrapper for a muted AVPlayer surface.
- Modify `FitGenius/Views/Plan/WorkoutDayDetailView.swift`: make the action body navigable without changing completion/edit/delete controls.
- Modify `FitGenius/en.lproj/Localizable.strings`: English copy.
- Modify `FitGenius/zh-Hans.lproj/Localizable.strings`: Simplified Chinese copy.
- Create `scripts/exercise-tutorial-catalog-tests.swift`: catalog model, filtering and lookup regressions.
- Create `scripts/video-comparison-timeline-tests.swift`: offset and normalized-progress regressions.
- Create `scripts/audit-exercise-tutorial-catalog.mjs`: check source traceability, duplicate IDs, time ranges and template IDs.
- Create `docs/exercise-tutorial-inventory.csv`: review queue for public Tan Sir videos and action segments.
- Modify `docs/form-coach-roadmap.md`: record the new learning loop and phased scope.
- Modify `docs/agent-handoff.md`: record implementation and validation evidence.

## Task 1: Tutorial Catalog Domain Model

**Files:**
- Create: `FitGenius/Models/Plan/ExerciseTutorialClip.swift`
- Create: `FitGenius/Services/ExerciseTutorialCatalog.swift`
- Create: `FitGenius/Resources/ExerciseTutorials/tutorial_clips.json`
- Create: `scripts/exercise-tutorial-catalog-tests.swift`

- [ ] **Step 1: Write the failing catalog regression test**

The test must decode one valid clip, reject an inverted time range, return clips for a matching template ID, and hide `developmentOnly` clips from release filtering:

```swift
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
require(valid.validationError == nil, "valid clip should pass")
require(ExerciseTutorialCatalog(clips: [valid]).clips(for: "0025").map(\.id) == ["tan-bench-001"], "template lookup")
require(ExerciseTutorialCatalog.visibleClips([valid], isDebug: false).isEmpty, "release must hide development media")
```

- [ ] **Step 2: Run the test and verify it fails because the types do not exist**

Run:

```bash
swiftc FitGenius/Models/Plan/ExerciseTutorialClip.swift \
  FitGenius/Services/ExerciseTutorialCatalog.swift \
  scripts/exercise-tutorial-catalog-tests.swift \
  -o /tmp/exercise-tutorial-catalog-tests
```

Expected: compilation fails with missing input files/types.

- [ ] **Step 3: Implement the catalog types and bundled loader**

Use a value type and an explicit validation result:

```swift
struct ExerciseTutorialClip: Codable, Identifiable, Hashable {
    enum RightsStatus: String, Codable { case developmentOnly, licensed, externalLinkOnly }
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
        if id.isEmpty { return "missing id" }
        if exerciseTemplateIDs.isEmpty { return "missing exercise template" }
        if clipStartSeconds < 0 || clipEndSeconds <= clipStartSeconds { return "invalid clip range" }
        return nil
    }
}
```

`ExerciseTutorialCatalog.loadBundled()` decodes `tutorial_clips.json`, discards invalid rows, applies DEBUG/Release rights filtering, and sorts clips by `clipStartSeconds` then `id`.

- [ ] **Step 4: Add a valid empty production-safe catalog resource**

Start with:

```json
{
  "schemaVersion": 1,
  "clips": []
}
```

Real mappings are added only after source/action/time-range review in Task 6.

- [ ] **Step 5: Run the catalog test**

Run the compile command from Step 2 followed by `/tmp/exercise-tutorial-catalog-tests`.

Expected: `exercise-tutorial-catalog-tests: PASS`.

- [ ] **Step 6: Commit the domain slice**

```bash
git add FitGenius/Models/Plan/ExerciseTutorialClip.swift \
  FitGenius/Services/ExerciseTutorialCatalog.swift \
  FitGenius/Resources/ExerciseTutorials/tutorial_clips.json \
  scripts/exercise-tutorial-catalog-tests.swift
git commit -m "feat: add exercise tutorial catalog"
```

## Task 2: Safe Plan-to-Template Resolution

**Files:**
- Create: `FitGenius/Services/ExerciseTemplateResolver.swift`
- Modify: `FitGenius/Services/AIService.swift`
- Extend: `scripts/exercise-tutorial-catalog-tests.swift`

- [ ] **Step 1: Add failing resolver assertions**

Cover punctuation/case normalization, one explicit alias, and ambiguity rejection:

```swift
let candidates = [
    ExerciseTemplateResolver.Candidate(id: "bench", names: ["barbell bench press", "杠铃卧推"]),
    ExerciseTemplateResolver.Candidate(id: "incline", names: ["incline bench press", "上斜卧推"])
]
require(ExerciseTemplateResolver.resolve("Barbell Bench-Press", in: candidates) == "bench", "normalized exact match")
require(ExerciseTemplateResolver.resolve("卧推", in: candidates) == "bench", "reviewed alias")
require(ExerciseTemplateResolver.resolve("bench press", in: candidates) == nil, "ambiguous fuzzy match must be rejected")
```

- [ ] **Step 2: Run and observe the missing resolver failure**

Compile the resolver with the existing catalog test. Expected: missing type failure.

- [ ] **Step 3: Implement deterministic matching**

Implement normalized exact-name matching first and a small reviewed alias table second. Never use edit-distance guessing when more than one candidate remains.

- [ ] **Step 4: Reuse the resolver from AI plan parsing**

Replace the private name matcher in `AIService` with the shared deterministic resolver while preserving current catalog injection and `Exercise.template` assignment.

- [ ] **Step 5: Run the catalog/resolver regression test**

Expected: PASS for exact/alias matches and ambiguity rejection.

- [ ] **Step 6: Commit the resolver slice**

```bash
git add FitGenius/Services/ExerciseTemplateResolver.swift FitGenius/Services/AIService.swift scripts/exercise-tutorial-catalog-tests.swift
git commit -m "feat: resolve planned exercises to catalog templates"
```

## Task 3: Planned Exercise Learning Page

**Files:**
- Create: `FitGenius/Views/Plan/PlannedExerciseDetailView.swift`
- Modify: `FitGenius/Views/Plan/WorkoutDayDetailView.swift`
- Modify: `FitGenius/en.lproj/Localizable.strings`
- Modify: `FitGenius/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Add a static regression check for the required learning sections**

Extend `scripts/exercise-tutorial-catalog-tests.swift` to read the new Swift source and require the prescription, GIF, instructions, tutorial CTA, unmatched fallback and form-analysis CTA identifiers.

- [ ] **Step 2: Verify the static test fails before the view exists**

Expected: FAIL reporting the missing view source.

- [ ] **Step 3: Implement `PlannedExerciseDetailView`**

The view accepts `@Bindable var exercise: Exercise`, queries available templates, resolves `exercise.template ?? resolver(name:)`, and renders:

```swift
Section("planned_exercise_prescription") { setsRepsWeightNotes }
if let template {
    AnimatedGIFView(urlString: template.gifUrl, cacheKey: template.mediaId ?? template.externalId)
    exerciseMetadata(template)
    instructions(template)
    tutorialButtons(catalog.clips(for: template.externalId))
} else {
    ContentUnavailableView("planned_exercise_unmatched_title", systemImage: "questionmark.circle", description: Text("planned_exercise_unmatched_message"))
}
```

Show the existing `FormAnalysisView` action only when `FormExerciseType.infer(from:)` succeeds.

- [ ] **Step 4: Make only the exercise content area navigable**

Refactor `ExerciseRowView` to accept `onOpen`. Wrap the name/prescription region in a plain button or navigation destination; preserve the separate completion button and overflow control.

- [ ] **Step 5: Add matching Chinese and English strings**

Include copy for prescription, standard demo, instructions, tutorial CTA, unavailable tutorial, source link, compare CTA, unmatched fallback and supported form analysis.

- [ ] **Step 6: Run localization and simulator build checks**

```bash
scripts/check-localization.sh
plutil -lint FitGenius/zh-Hans.lproj/Localizable.strings FitGenius/en.lproj/Localizable.strings
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FitGenius.xcodeproj -scheme FitGenius \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FitGeniusExerciseLearningDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: localization PASS, plist OK, build SUCCEEDED.

- [ ] **Step 7: Commit the learning-page slice**

Stage only the relevant hunks in `WorkoutDayDetailView.swift` and the localization files because they already contain unrelated user work.

## Task 4: Comparison Timeline Policy

**Files:**
- Create: `FitGenius/Models/Plan/VideoComparisonTimeline.swift`
- Create: `scripts/video-comparison-timeline-tests.swift`

- [ ] **Step 1: Write failing timeline tests**

Cover reference/user offsets, normalized progress, shorter-video clamping and supported playback rates:

```swift
let timeline = VideoComparisonTimeline(referenceDuration: 12, userDuration: 10, referenceOffset: 2, userOffset: 1)
require(timeline.referenceTime(progress: 0.5) == 7, "reference midpoint")
require(timeline.userTime(progress: 0.5) == 5.5, "user midpoint")
require(timeline.clampedRate(0.4) == 0.5, "rate snaps to supported value")
```

- [ ] **Step 2: Verify the test fails because the policy does not exist**

```bash
swiftc FitGenius/Models/Plan/VideoComparisonTimeline.swift scripts/video-comparison-timeline-tests.swift -o /tmp/video-comparison-timeline-tests
```

- [ ] **Step 3: Implement the pure timeline policy**

Use the shorter available segment as the common duration, clamp progress to `0...1`, map it through each offset, and support `[0.25, 0.5, 1.0]` rates.

- [ ] **Step 4: Run and pass the timeline tests**

Expected: `video-comparison-timeline-tests: PASS`.

- [ ] **Step 5: Commit the policy slice**

```bash
git add FitGenius/Models/Plan/VideoComparisonTimeline.swift scripts/video-comparison-timeline-tests.swift
git commit -m "feat: add synchronized comparison timeline"
```

## Task 5: Tutorial Player and Side-by-Side Comparison

**Files:**
- Create: `FitGenius/Views/Components/ControlledVideoPlayer.swift`
- Create: `FitGenius/Views/Plan/ExerciseTutorialView.swift`
- Create: `FitGenius/Views/Plan/ExerciseVideoComparisonView.swift`
- Modify: `FitGenius/en.lproj/Localizable.strings`
- Modify: `FitGenius/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Implement a controlled, muted AVPlayer surface**

Wrap `AVPlayerLayer` in `UIViewRepresentable`; player creation, observers and transport remain owned by the parent controller/view model so SwiftUI updates do not create duplicate audio or players.

- [ ] **Step 2: Implement tutorial playback boundaries**

Create an `AVPlayer` for `playbackURL`, seek to `clipStartSeconds`, and observe time so playback pauses or loops at `clipEndSeconds`. Show creator, source title, original URL and localized framing note below the player.

- [ ] **Step 3: Add user video selection**

Use `PhotosPicker(selection:matching: .videos)` and copy the selected transferable data into a unique file in `FileManager.default.temporaryDirectory`. Delete that temporary file when the comparison flow is dismissed.

- [ ] **Step 4: Build the comparison view**

Display two fixed-aspect player surfaces in an `HStack`, labels above each side, one common play/pause button, one progress slider, a segmented playback-rate picker, and separate start-offset steppers/sliders.

- [ ] **Step 5: Synchronize transport**

On play and after each seek, map common progress through `VideoComparisonTimeline`, seek both players with a small tolerance, set equal playback rates, then play. Pause both players on disappearance and scene deactivation.

- [ ] **Step 6: Add error and no-playback fallbacks**

If `playbackURL` is absent, show the original source link and do not expose compare. If user video decoding fails, keep the tutorial visible and allow reselection.

- [ ] **Step 7: Run timeline, localization and Xcode build checks**

Expected: both Swift script suites PASS; localization PASS; simulator build SUCCEEDED.

- [ ] **Step 8: Commit the playback slice**

Stage only the new views and the newly added localization lines.

## Task 6: Tan Sir Inventory and First Reviewed Mappings

**Files:**
- Create: `scripts/audit-exercise-tutorial-catalog.mjs`
- Create: `docs/exercise-tutorial-inventory.csv`
- Modify: `FitGenius/Resources/ExerciseTutorials/tutorial_clips.json`
- Modify: `.gitignore`

- [ ] **Step 1: Protect local media from Git**

Add:

```gitignore
video/tutorial-source/
video/tutorial-clips/
```

- [ ] **Step 2: Create the inventory schema**

Use CSV columns:

```text
source_platform,source_video_id,source_url,source_title,published_at,exercise_template_ids,clip_start_seconds,clip_end_seconds,camera_view,rights_status,review_status,notes
```

- [ ] **Step 3: Inventory the official Bilibili list metadata**

Use the confirmed creator list `https://www.bilibili.com/list/521903482/` as the first source. Record metadata and links without treating title-only guesses as approved action mappings.

- [ ] **Step 4: Add an audit script**

The script loads `exercises_seed.json` and `tutorial_clips.json`; it fails on duplicate clip IDs, unknown template IDs, invalid ranges, missing source traceability, or a `licensed` row without a playback URL.

- [ ] **Step 5: Review and add the first playable development mappings**

For each selected source, manually confirm the action and time range. Keep the row `developmentOnly` until authorization. Store any downloaded source and transcoded clip under the ignored `video/tutorial-*` directories.

- [ ] **Step 6: Run the audit**

```bash
node scripts/audit-exercise-tutorial-catalog.mjs
```

Expected: prints counts for clips, mapped templates and missing playback assets, then exits 0.

- [ ] **Step 7: Commit metadata and tooling, not binaries**

```bash
git add .gitignore scripts/audit-exercise-tutorial-catalog.mjs docs/exercise-tutorial-inventory.csv FitGenius/Resources/ExerciseTutorials/tutorial_clips.json
git commit -m "content: add Tan Sir exercise tutorial inventory"
```

## Task 7: Documentation and End-to-End Verification

**Files:**
- Modify: `docs/form-coach-roadmap.md`
- Modify: `docs/agent-handoff.md`

- [ ] **Step 1: Update the product roadmap**

Record the new learning loop, the optional tutorial relationship, the first-version manual same-angle comparison, and the deferred automatic camera-angle/action-phase work.

- [ ] **Step 2: Run all targeted checks**

```bash
/tmp/exercise-tutorial-catalog-tests
/tmp/video-comparison-timeline-tests
node scripts/audit-exercise-tutorial-catalog.mjs
scripts/check-localization.sh
git diff --check
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FitGenius.xcodeproj -scheme FitGenius \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FitGeniusExerciseLearningDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 3: Install and launch in an iPhone simulator**

Boot an available iPhone simulator, install the built `.app`, launch `com.swordingk.fitgenius`, and verify the process stays running.

- [ ] **Step 4: Perform the manual acceptance flow**

Verify one mapped and one unmapped exercise: open from the plan, inspect the GIF/instructions, play the reference clip, select a user video, adjust offsets, play at 0.5x, dismiss, and confirm both players stop.

- [ ] **Step 5: Update handoff evidence**

Record which layers passed: unit scripts, catalog audit, build, simulator install/launch and manual interaction. Keep creator authorization and physical-device media acceptance explicitly pending until completed.

- [ ] **Step 6: Commit documentation and final scoped changes**

Do not include pre-existing health, Watch, AI, website or Xcode user-data changes.

## Plan Self-Review

- Spec coverage: plan entry, standard GIF/instructions, optional creator clip, same-angle guidance, side-by-side comparison, rights gating, missing-content degradation, content inventory and validation all have tasks.
- Scope: automatic camera-angle validation, phase alignment and broad pose scoring remain excluded.
- Type consistency: tutorial lookup uses `ExerciseTemplate.externalId`; comparison uses normalized progress plus per-video offsets; Release filtering uses `RightsStatus`.
- Workspace safety: relevant dirty files require hunk-level staging; unrelated work must remain untouched.
