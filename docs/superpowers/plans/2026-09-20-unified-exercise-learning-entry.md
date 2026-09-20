# Unified Exercise Learning Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the exercise library and workout plan open the same template-backed learning experience, while keeping unmatched plan exercises on a compact fallback and making library search permanently visible.

**Architecture:** `ExerciseTemplate` remains the canonical learning-content key. A reusable `ExerciseLearningContent` renders GIF, metadata, instructions, optional tutorial clips, and optional form analysis; `ExerciseDetailView` and `PlannedExerciseDetailView` only add entry-specific controls around it. `ExerciseTutorialView` accepts the template and clip directly because comparison does not depend on a persisted plan `Exercise`.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation, PhotosUI, bundled tutorial JSON, Swift script regression tests, Xcode 27 device build.

---

## File Map

- Create `FitGenius/Views/Plan/ExerciseLearningContent.swift`: canonical template-backed learning sections shared by library and plan details.
- Modify `FitGenius/Views/Plan/ExerciseDetailView.swift`: embed shared learning content and retain Add to Plan.
- Modify `FitGenius/Views/Plan/PlannedExerciseDetailView.swift`: retain prescription/unmatched fallback, but delegate matched content to the shared component.
- Modify `FitGenius/Views/Plan/ExerciseTutorialView.swift`: remove the unused `Exercise` dependency so library templates can open tutorials directly.
- Modify `FitGenius/Views/Plan/ExerciseLibraryView.swift`: replace collapsed system search with a persistent visible search field and include equipment text in matching.
- Modify `scripts/exercise-tutorial-catalog-tests.swift`: static regressions for both entry points, tutorial independence, fallback, and visible search.
- Modify `docs/form-coach-roadmap.md` and `docs/agent-handoff.md`: record the corrected product relationship and validation.

## Task 1: Lock the Product Contract with Failing Regressions

**Files:**
- Modify: `scripts/exercise-tutorial-catalog-tests.swift`

- [ ] **Step 1: Add source-contract checks**

Add checks that require:

```swift
requireSource("FitGenius/Views/Plan/ExerciseLibraryView.swift", contains: ["TextField", "exercise_library_search_placeholder"])
requireSource("FitGenius/Views/Plan/ExerciseDetailView.swift", contains: ["ExerciseLearningContent(template: template)"])
requireSource("FitGenius/Views/Plan/PlannedExerciseDetailView.swift", contains: ["ExerciseLearningContent(template: template", "planned_exercise_unmatched_title"])
requireSource("FitGenius/Views/Plan/ExerciseTutorialView.swift", excludes: ["let exercise: Exercise", "exercise: Exercise"])
```

The helper must fail with the exact missing marker and support both required and forbidden markers.

- [ ] **Step 2: Run the existing Swift regression test and observe RED**

Run:

```bash
swiftc \
  FitGenius/Models/Plan/ExerciseTutorialClip.swift \
  FitGenius/Models/Plan/VideoComparisonTimeline.swift \
  FitGenius/Services/ExerciseTutorialCatalog.swift \
  FitGenius/Services/ExerciseTemplateResolver.swift \
  scripts/exercise-tutorial-catalog-tests.swift \
  -o /tmp/exercise-tutorial-catalog-tests && \
/tmp/exercise-tutorial-catalog-tests
```

Expected: FAIL because the library detail does not contain shared learning content and the tutorial still requires `Exercise`.

## Task 2: Create One Template-Backed Learning Surface

**Files:**
- Create: `FitGenius/Views/Plan/ExerciseLearningContent.swift`
- Modify: `FitGenius/Views/Plan/ExerciseDetailView.swift`
- Modify: `FitGenius/Views/Plan/PlannedExerciseDetailView.swift`
- Modify: `FitGenius/Views/Plan/ExerciseTutorialView.swift`

- [ ] **Step 1: Extract template content**

Create a `View` accepting:

```swift
struct ExerciseLearningContent: View {
    let template: ExerciseTemplate
    var formAnalysisExercise: Exercise? = nil
}
```

It loads `ExerciseTutorialCatalog`, renders the existing standard demo, metadata and instructions, and creates:

```swift
NavigationLink {
    ExerciseTutorialView(template: template, clip: clip)
} label: {
    Label("planned_exercise_watch_tutorial", systemImage: "play.rectangle.fill")
}
```

When clips are empty it renders the localized unavailable state. It only exposes `FormAnalysisView` when a concrete plan exercise exists and is supported.

- [ ] **Step 2: Make the tutorial independent from plans**

Change its initializer to:

```swift
init(template: ExerciseTemplate, clip: ExerciseTutorialClip) {
    self.template = template
    self.clip = clip
    _playback = StateObject(wrappedValue: TutorialPlaybackController(clip: clip))
}
```

No behavior in playback, PhotosPicker, or comparison changes.

- [ ] **Step 3: Compose both details from the shared content**

`ExerciseDetailView` places `ExerciseLearningContent(template: template)` before attribution/Add to Plan. `PlannedExerciseDetailView` keeps prescription first and, when resolved, uses:

```swift
ExerciseLearningContent(template: template, formAnalysisExercise: exercise)
```

When no template resolves, it keeps only prescription, notes, and the current unmatched explanation.

- [ ] **Step 4: Run the regression test and expect the shared-entry checks to pass**

Run the command from Task 1. Expected: it advances past the shared-entry assertions.

## Task 3: Make Search Permanently Discoverable

**Files:**
- Modify: `FitGenius/Views/Plan/ExerciseLibraryView.swift`

- [ ] **Step 1: Add a persistent search field above filters**

Use a visible rounded field:

```swift
HStack(spacing: 8) {
    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
    TextField("exercise_library_search_placeholder".localized, text: $searchText)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    if !searchText.isEmpty {
        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
    }
}
```

Place it above the two filter rows and remove `.searchable` so there is only one obvious search interaction.

- [ ] **Step 2: Include localized equipment text in the search haystack**

Append the template's localized equipment category to the existing English name, Chinese name, body part, target muscle, and focus terms.

- [ ] **Step 3: Run the regression test and expect GREEN**

Run the Task 1 command. Expected: `exercise-tutorial-catalog-tests: PASS`.

## Task 4: Validate, Document, Build, Install, and Launch

**Files:**
- Modify: `docs/form-coach-roadmap.md`
- Modify: `docs/agent-handoff.md`

- [ ] **Step 1: Run focused validation**

```bash
/tmp/exercise-tutorial-catalog-tests
swiftc FitGenius/Models/Plan/VideoComparisonTimeline.swift scripts/video-comparison-timeline-tests.swift -o /tmp/video-comparison-timeline-tests && /tmp/video-comparison-timeline-tests
node scripts/tutorial-catalog-audit-tests.mjs
node scripts/audit-exercise-tutorial-catalog.mjs
scripts/check-localization.sh
git diff --check
```

Expected: every command passes.

- [ ] **Step 2: Record the canonical relationship**

Document that plan exercises resolve to `ExerciseTemplate`; matched exercises reuse the library detail, unmatched exercises degrade to prescription/notes, and tutorial clips remain optional.

- [ ] **Step 3: Build for the connected iOS 27 device**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project FitGenius.xcodeproj -scheme FitGenius \
  -configuration Debug \
  -destination 'platform=iOS,id=00008120-00043C660E83601E' \
  -derivedDataPath /tmp/FitGeniusXcode27DeviceBuild \
  -allowProvisioningUpdates build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Install and launch the new build**

```bash
xcrun devicectl device install app --device 00008120-00043C660E83601E \
  /tmp/FitGeniusXcode27DeviceBuild/Build/Products/Debug-iphoneos/FitGenius.app
xcrun devicectl device process launch --device 00008120-00043C660E83601E \
  --terminate-existing com.swordingk.fitgenius
```

Expected: install and launch both report success. Manual acceptance searches for `哑铃侧平举` in the library, opens it directly, plays the Tan Sir clip, and reaches the comparison picker without first adding it to a plan.

## Self-Review

- Spec coverage: permanent search, shared template detail, plan fallback, optional tutorial, comparison reachability, storage model, device verification all have explicit tasks.
- Placeholder scan: no TBD/TODO or unspecified implementation steps remain.
- Type consistency: `ExerciseLearningContent` is keyed by `ExerciseTemplate`; `ExerciseTutorialView` needs only template plus clip; `Exercise` is optional and used solely for plan-specific form analysis.
