# FitGenius Agent Handoff

Last updated: 2026-10-03 Asia/Shanghai

## Read First

1. `AGENTS.md`
2. `docs/form-coach-roadmap.md`
3. `docs/product-quality-plan.md`
4. `docs/agent-handoff.md`

## Current Status

### 2026-10-03: Common-exercise tutorial batch

- The first batch now has 24 distinct exercise templates with hosted, playable
  development excerpts (15.5–27 seconds), not just source links or candidates.
  `docs/tutorial-batch-acceptance.md` lists exact IDs, source timestamps, hosted
  MP4 URLs and asset SHA-256 values for owner review.
- Main-agent visual review consumed the local audit records in
  `docs/tutorial-reviews/`. Matching checks actual canonical GIFs, equipment,
  grip and posture; similar but unsupported variants stay unpublished. Several
  sources are coached trainee footage or Tan Sir / Kai Sheng Wang collaborations.
- All 24 assets were uploaded before the cloud manifest. The existing two
  clip IDs were retained; no App code, NoSQL collection or cloud function was
  changed. Fifteen complete original sources are retained outside Git.
- Video binaries remain in CloudBase Hosting/object storage and metadata in
  a versioned cloud JSON catalog. Debug can play these development clips;
  Release still hides them. No merge or release submission.

### 2026-10-03: Initial cloud tutorial catalog and official Douyin research

- Shared library/plan details now load the CloudBase `exercise-tutorials/catalog-v1.json`
  catalog, keep an atomic last-good disk cache, and retain bundled fallback.
  A shared observable store coalesces requests and refreshes successful loads after
  six hours; failure does not block the exercise/GIF detail.
- Uploaded two development excerpts: lateral raise (source 132–151s, 19 seconds,
  template `0334`) and overhand wide pulldown (350–375s, 25 seconds, template
  `0198`) to scoped CloudBase Hosting. They are `developmentOnly`, hidden
  in Release. The stable legacy clip ID replaces the bundled sample when the
  cloud catalog loads; source metadata now points to the verified Douyin original.
- Published separate external-source links for both exercises. Link-only
  entries are labelled as sources and do not offer in-App side-by-side playback.
- `docs/tutorial-sources/douyin-tan.json` records 49 official-profile teaching
  sources and 24 candidate template matches. Two complete originals are kept
  under ignored `video/tutorial-source/douyin/`; RDL download timed out and is
  not marked downloaded. Research is NOT complete: 1300 templates remain
  unreviewed, and candidates are not published as reviewed tutorials.
- CloudBase gateway GET with `Range: bytes=0-1023` returned the full MP4 (200),
  while the direct private COS origin returned 403. No bucket permissions were
  broadened. Added on-demand short-excerpt disk caching (20 MB per asset, 250 MB
  oldest-first cache budget); playback/comparison share the cached file for seeking.
  The first load shows progress and retry on failure; this is not progressive streaming.
- Storage is now cloud-hosted metadata + HTTPS media, not video blobs inside
  SwiftData or a bundled library. No NoSQL tutorial collection was created:
  the current cloud catalog is versioned JSON, an explicit intermediate index.
- Existing user Xcode scheme changes and the unrelated untracked Remotion
  `video/` project were preserved. No branch merge or release submission.

### 2026-09-21: Progressive entry and AI plan proposal flow

- First launch now enters the main product directly. If no plan exists, the
  current-plan store creates one standalone empty workout plan without
  inventing a user profile.
- The dashboard, exercise-library add flow, Widget, cloud snapshot selection,
  reminders, and AI Assistant share the same current-plan policy: newest
  profile-linked plan first, otherwise newest standalone plan.
- The empty dashboard is a usable state with separate personalized-generation
  and manual-create actions. Resetting all data recreates an empty draft instead
  of returning to a mandatory onboarding gate.
- Profile setup no longer deletes existing profiles or manual plans. Existing
  training content is passed into regeneration context, and the generated plan
  is reviewed before it replaces the current plan.
- General AI text questions now work without Profile data. Available Profile,
  plan, conversation, and opted-in health context are added progressively.
- Local exercise edits and full plan replacements are pending proposals. They
  pass deterministic local validation and show a preview before an explicit
  apply action. Cancellation and invalid proposals do not write SwiftData.
- Removed local keyword/regex routing for plan rewrites. The model returns a
  structured regenerate-plan intent; the app generates a complete candidate,
  validates it, and previews it.
- Exercise catalog prompt entries now use stable ID, canonical English name,
  and Chinese name instead of locale-dependent display names.

### 2026-09-20: Unified exercise-library learning entry

- Corrected the learning architecture after physical-device review: tutorial
  content no longer exists only behind a workout-plan row. Both the exercise
  library and a template-backed plan exercise now compose the same
  `ExerciseLearningContent` keyed by `ExerciseTemplate.externalId`.
- The exercise library now has a permanently visible search field above its
  body-part and equipment filters. Search still matches English and Chinese
  names, body part, target muscle, and focus, and now also matches localized
  equipment names.
- `ExerciseTutorialView` no longer requires an `Exercise` instance; a library
  template with a mapped clip can open playback, Photos selection, and manual
  side-by-side comparison without first being added to a plan.
- Plan exercises retain their prescription. A resolved template shows the
  shared library learning content; an unresolved/custom plan action safely
  remains on the compact unmatched explanation.
- Current media storage remains development-only: the reviewed lateral-raise
  MP4 is bundled only into Debug builds on the device, while tutorial metadata
  is bundled JSON. Production should store authorized video binaries in
  CloudBase Storage/CDN and keep only template IDs, URLs, source and rights
  metadata in the catalog/database.

### 2026-09-19: Exercise learning and same-angle comparison vertical slice

- Every planned exercise row can now open a dedicated learning detail while
  its completion checkbox and overflow menu remain independent controls.
- The detail resolves generated plan names to the canonical exercise library,
  then shows the existing GIF, prescription, equipment, muscle/difficulty
  metadata, instructions, and the existing form-analysis entry when supported.
- A data-driven tutorial catalog now maps library template IDs to source and
  playback metadata. Missing or unavailable clips fail softly instead of
  blocking the exercise detail.
- Tutorial playback supports a local development asset or a future hosted URL.
  The first reviewed development excerpt maps dumbbell lateral raise (`0334`)
  to 00:02:12-00:02:31 of the source video. The downloaded source and excerpt
  are intentionally gitignored.
- Users can select their own video from Photos and compare it with the tutorial
  side by side. Both players share play/pause, scrub, and speed controls, with
  independent manual offsets for same-angle phase matching. Automatic angle or
  repetition alignment remains out of scope for this version.
- The initial Tan Sir source inventory is recorded in
  `docs/exercise-tutorial-inventory.csv`; unreviewed or unmatched exercises are
  intentionally allowed to remain empty.

### 2026-08-03: Release security gate

- Release preflight found that the tracked `cloudbaserc.json` contained a real
  MiniMax provider key and CloudBase session-signing secret. Both values were
  removed from the working tree; deployable-file secret scan now passes.
- **Do not deploy or submit this release until the owner rotates both values**:
  revoke/create a MiniMax API key, then set the new `MINIMAX_API_KEY` and a new
  random `SESSION_SECRET` in the CloudBase `fitgenius-api` production function
  environment. Rotating `SESSION_SECRET` will intentionally require existing
  users to sign in with Apple again. The old values appeared in Git history, so
  rotation is mandatory even if the repository history is cleaned later.
- Verification after removal: backend tests 26/26 passed, iOS form-analysis
  suite passed, localization and `git diff --check` passed, deployable-file
  secret scan passed, and a clean-directory unsigned Release iOS build passed.
  This is a build-quality result, not a confirmation of the CloudBase runtime
  environment or real Apple Watch HealthKit data.

### 2026-08-02: Health-report trust hardening and onboarding polish

- Daily readiness no longer treats missing training history as a neutral
  72-point load signal. Training load only contributes when FitGenius has real
  completed-exercise history, so sleep-only data remains explicitly
  `insufficientData` instead of claiming a confident ready-to-train state.
- Daily readiness now records a 0-100 data-coverage percentage based on the
  scoring signals actually available for that day. The Stats card exposes this
  as a transparency cue and explicitly says it is coverage of FitGenius
  signals, not medical accuracy. The field is optional in cloud snapshots so
  existing account backups continue to decode safely.
- Weekly reporting now uses a reusable Monday-to-Monday half-open range:
  `[Monday 00:00, next Monday 00:00)`. Sunday daytime exercise logs are
  included; next Monday is excluded. The report record still displays Sunday
  as the human-readable end date.
- Onboarding dismisses the basic-info keyboard before moving to the goal step.
  The Notes page no longer registers a second keyboard toolbar while alive in
  the onboarding `TabView`, removing the duplicate Done controls observed in
  the Simulator.
- Added `scripts/recovery-insight-engine-tests.swift` coverage for the
  sleep-only confidence regression and
  `scripts/health-report-week-range-tests.swift` for the Sunday/Monday range
  boundary. The recovery test also asserts 35% coverage for a sleep-only
  report and 100% coverage when every weighted signal is present.
- Missing overnight sleep is represented as unavailable, not a visible 50%
  sleep-recovery value. It receives zero score weight when HealthKit has no
  sleep sample, and the AI context receives an explicit unavailable value.

### 2026-08-03: AI Assistant conversation sessions

- Fitness AI Assistant and Diet AI Assistant no longer open the entire
  topic-wide transcript as one endless conversation. New messages receive a
  local `conversationID`; each assistant starts with a clean current session,
  offers New Conversation and Chat History controls, and sends recent context
  only from the active session.
- Existing `ChatMessage` rows keep a nil `conversationID` and remain readable
  under one localized Earlier Conversation entry. This is intentionally an
  additive SwiftData migration: old chats are not deleted, and no CloudBase
  endpoint or AI request contract changes.
- Chat history is derived from local messages rather than a second SwiftData
  table. A user can select or delete one session; the existing destructive
  Clear All History control remains available in the overflow menu.
- Added `ChatSessionPolicy` plus
  `scripts/chat-session-policy-tests.swift` for title fallback/truncation and
  active-session ordering. This checks the user-visible session behavior
  without coupling the test to a SwiftData store.

### 2026-08-03: Health-AI context activation and assistant chrome

- Root cause from physical-iPhone feedback: `AIService.chat` has always
  serialized and sent the current training plan, but health context is
  intentionally opt-in and `HealthContextBuilder` can only inject stored local
  summaries. The Profile authorization button previously requested HealthKit
  access without immediately refreshing those summaries, making a newly
  authorized user appear to have no health-aware AI.
- Profile now refreshes `HealthInsightViewModel` immediately after HealthKit
  authorization. The Fitness AI Assistant displays whether it will use only
  the plan, needs a report refresh, or can use authorized health summaries;
  its setup action takes the user directly to Profile. This is a transparency
  improvement, not permission bypassing: AI health use remains off until the
  user explicitly enables it.
- Product correction from physical-iPhone feedback: the global Diet / Training
  switch is required navigation and remains available. Both AI pages instead
  omit their redundant navigation title (the tab bar already identifies the
  assistant), preventing overlap without removing the switch.
- Added `AssistantHealthContextStatus` and
  `scripts/assistant-health-context-tests.swift` for the three privacy/data
  states plus a static regression check that both AI pages keep the global
  mode switch and omit only their duplicate titles.

### 2026-08-03: Watch live-workout authority

- The Watch app already had a real `HKWorkoutSession` and
  `HKLiveWorkoutBuilder`, but its start control was only a small icon and the
  iPhone completion path could also save a basic post-hoc workout. The Watch UI
  now presents a full-width Start Workout / End Workout control.
- A successful Watch start and end are sent to the iPhone via
  `WatchConnectivity`. While a same-day Watch session is active, completing the
  plan suppresses the iPhone fallback workout, letting the Apple Watch record
  remain authoritative for real heart-rate and active-energy collection. A
  stale session flag expires automatically on a new day.
- Added `WorkoutHealthSavePolicy` plus
  `scripts/workout-health-save-policy-tests.swift` for the duplicate-prevention
  contract. iOS Simulator and watchOS Simulator builds passed; the Watch app
  was installed and launched on an Apple Watch Series 11 (46mm) simulator.
  Physical Watch acceptance must still confirm the Health permission prompt,
  live heart rate, active energy, and Fitness-ring behavior.

Health Intelligence milestone started on 2026-07-29:

- 2026-08-03 nutrition-sync pass: Profile now has a separate opt-in setting
  to write the user's confirmed daily calories, protein, carbohydrates, and
  fat totals to Apple Health. `HealthKitNutritionService` replaces only the
  four FitGenius-tagged samples for that day after meal analysis, manual edits,
  or deletion; meal photos, meal descriptions, and per-meal detail remain local.
  `HealthKitWorkoutService` still writes only a completed strength-workout type
  and duration. It does not claim live heart rate, active energy, rings, or
  location because a post-hoc iPhone record cannot legitimately collect them.
- Validation: `health-nutrition-sync-policy-tests`,
  `recovery-insight-engine-tests`, `scripts/check-localization.sh`, plist
  lint, privacy-policy copy parity, `git diff --check`, and iPhone 17 Pro
  Simulator build/install/launch passed. Real-device acceptance is still
  required for the Apple Health authorization prompt and the four written
  nutrition quantities.

- Added the first iOS-side Health Intelligence layer: SwiftData models for
  daily HealthKit summaries, daily readiness reports, weekly health reports,
  and report preferences; a HealthKit reader for activity, workouts, heart
  rate, resting heart rate, HRV, sleep, advanced vitals, and body metrics; a
  deterministic recovery engine; and an AI health-context builder.
- Stats now has a top-level "Today's Body Status" card. It connects Apple
  Health, refreshes today's readiness, shows score/evidence/training advice,
  and keeps the copy scoped to training recovery rather than medical diagnosis.
- Profile now includes Apple Health & Body Reports settings for AI health
  context, advanced vitals, body metrics, and report-data authorization.
- Fitness AI Assistant now injects health context only when the user enables
  it, and includes quick health questions such as "Am I ready to train today?"
  and "Generate this week's body report."
- Cloud account snapshots now include bounded health summary/report records
  as schemaVersion 2 optional fields, preserving old snapshot compatibility and
  avoiding raw HealthKit sample sync.
- Privacy policy and HealthKit permission copy were updated to disclose Apple
  Health usage and AI summary upload boundaries.
- 2026-07-31 report-depth pass: the Stats entry is no longer only a compact
  score card. `HealthReadinessCard` now links to a full Body Report view with
  Today / This Week tabs, daily metric modules for sleep, HRV, resting heart
  rate, activity, sleep recovery, and training advice, an evidence section,
  Apple Watch signal modules when sleep stages / HRV / SpO2 / VO2 Max data
  exists, a basic-data hint when those signals are unavailable, weekly report
  summary/advice cards, and a 7-day trend strip.
- `RecoveryInsightEngine` daily reports now keep up to 5 evidence reasons
  instead of hiding available nutrition/training context behind a 3-item cap.
- 2026-07-30 compile incident: Xcode initially failed because
  `HealthInsightViewModel` used `ObservableObject`/`@Published` without
  importing Combine. Fixed by adding `import Combine` and removing the
  `HealthDataService.shared` default-argument concurrency warning.
- Latest validation after the fix:
  - iOS simulator build passed with
    `xcodebuild -quiet -project FitGenius.xcodeproj -scheme FitGenius
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1'
    CODE_SIGNING_ALLOWED=NO build`.
  - Physical-iPhone architecture build passed with
    `xcodebuild -quiet -project FitGenius.xcodeproj -scheme FitGenius
    -destination 'platform=iOS,name=宝剑的iPhone'
    CODE_SIGNING_ALLOWED=NO build`.
  - `recovery-insight-engine-tests`: PASS.
  - 2026-07-31: `recovery-insight-engine-tests` adds assertions that daily and
    weekly reports expose multi-factor evidence when data is available; PASS.
  - `plutil -lint FitGenius/Info.plist FitGenius/PrivacyInfo.xcprivacy`: OK.
  - `plutil -lint FitGenius/zh-Hans.lproj/Localizable.strings
    FitGenius/en.lproj/Localizable.strings`: OK.
  - `scripts/check-localization.sh`: PASS.
  - 2026-07-31 simulator smoke test installed and launched
    `/tmp/FitGeniusDerivedData/Build/Products/Debug-iphonesimulator/FitGenius.app`
    on iPhone 17 Pro simulator; launch returned process id 37749.
  - Remaining warning is pre-existing/older code:
    `HealthKitWorkoutService` uses deprecated `HKWorkout(...)` initializer;
    it does not block compilation and was not changed in this pass to avoid
    destabilizing workout saving before release.

MiniMax provider migration is deployed and verified:

- The public iOS API remains `/api/ai/chat`; released builds are not forced to
  update and continue to authenticate with the same FitGenius session token.
- The backend now has a provider-neutral adapter. It maps both legacy Qwen
  model names and new `fitgenius-text`, `fitgenius-vision`, and
  `fitgenius-video` aliases to `MiniMax-M3` when `AI_PROVIDER=minimax`.
- MiniMax uses `reasoning_split: true` so internal reasoning is not rendered in
  the user-visible chat response. Aliyun remains an environment-only emergency
  rollback path.
- Direct provider probes confirmed the supplied China-region credential works
  for text, image, video, and streaming requests at `api.minimaxi.com`. The key
  has not been written to the repository or iOS bundle.
- Production Vercel deployment `dpl_14CsiwMuA62xRMbzs73S2ML1FDmr` is READY and
  aliased to `https://fitgenius-ashen.vercel.app`. Production now has encrypted
  `MINIMAX_API_KEY` plus `AI_PROVIDER=minimax`; the prior Aliyun credential is
  retained for emergency rollback.
- Production health returned HTTP 200 and unauthenticated AI requests returned
  HTTP 401. An authenticated in-app smoke test still requires a real Apple
  session because Vercel sensitive values cannot be pulled back to mint a local
  production session.
- The iPhone app, Widget, and Watch targets are aligned for release version
  `1.2` with build number `2`.
- On 2026-06-23, the pre-App-Store polish pass improved the AI Assistant and
  onboarding experience: AI replies are cleaned before display so Markdown
  markers such as `#`, `**`, and code fences do not leak into chat bubbles;
  Fitness and Diet assistants now include bounded recent conversation context
  in requests while still keeping full history visible locally; fitness AI
  system/action replies are inserted into SwiftData consistently; onboarding
  now includes Strength and Sport Performance goals plus notes guidance for
  basketball, competition prep, posture, recovery, weekly availability, and
  specific lift-performance needs. Training-plan prompts now treat sport
  performance and strength as first-class plan-generation goals instead of
  falling back to generic bodybuilding templates.

Android client kickoff is now in progress. The Android work must stay isolated
under `android/` so the existing iOS SwiftUI app, Watch app, Widget, and Xcode
project remain stable. The first Android milestone is a native Kotlin + Jetpack
Compose debug APK with the same core FitGenius product structure: Training,
Diet, AI Assistant, and Form Coach. Android widgets, Wear OS/Huawei watch,
HarmonyOS NEXT native work, and store release automation are intentionally
deferred.

Android milestone achieved on 2026-06-12:

- Installed local Android build tooling on this Mac: Homebrew `openjdk@17`,
  `android-commandlinetools`, Gradle, Android SDK Platform 35, Platform Tools,
  and Build Tools 34/35.
- Added an isolated Android Gradle project in `android/` with package
  `com.swordingk.fitgenius`, Kotlin, Jetpack Compose, Material 3, bilingual
  string resources, and Gradle Wrapper 8.10.2.
- Added first product shell: Training, Diet, AI Coach, and Form Coach tabs.
  It uses local sample data for now; backend auth/sync, real AI calls,
  image/video picking, and MediaPipe pose extraction are next milestones.
- Added JVM unit tests for workout progress and nutrition macro aggregation.
- Verified with:
  `JAVA_HOME=/opt/homebrew/opt/openjdk@17 ANDROID_HOME=/opt/homebrew/share/android-commandlinetools ./gradlew testDebugUnitTest assembleDebug --no-daemon`
- Result: `BUILD SUCCESSFUL`; debug APK generated at
  `android/app/build/outputs/apk/debug/app-debug.apk` (about 9.5 MB).

Android interaction milestone achieved on 2026-06-12:

- Added `FitGeniusState` reducer logic for completing workout sets, adding and
  deleting meals, and appending local assistant messages.
- Added JVM tests for those reducers, including guardrails that completed sets
  cannot exceed the programmed set count.
- Updated the Compose shell so Training can complete sets, Diet can add/delete
  meals, and AI Coach can show a local chat transcript.
- Re-ran
  `JAVA_HOME=/opt/homebrew/opt/openjdk@17 ANDROID_HOME=/opt/homebrew/share/android-commandlinetools ./gradlew testDebugUnitTest assembleDebug --no-daemon`;
  result: `BUILD SUCCESSFUL`.

Current local working-tree notes:

- `FitGenius.xcodeproj/xcuserdata/.../xcschememanagement.plist` has a
  pre-existing Xcode scheme-order change for the Watch scheme.
- `HYBRID_AI_UPGRADE_PLAN.md` is an untracked local planning file.
- Do not revert or fold unrelated local files into product work unless the
  user explicitly asks.

The cloud-sync and Apple Watch milestone is committed at `bafaf2e`, the
form-coach product-quality milestone is committed at `ab59258`, and the
form-keyframe / Widget TestFlight fix is committed at `e715c2d`. The current
local milestone upgrades AI Assistant video-analysis copy from a terse
detection report into structured coaching feedback.

Latest milestone:

- Hybrid AI upgrade is in progress for the two user-visible weak spots:
  Diet image recognition and AI Assistant form coaching. `AIService` now uses
  explicit `AIModelRouting`: training-plan generation/regeneration, pure text
  Diet chat, pure text nutrition JSON analysis, and Diet image chat / Diet
  image JSON analysis use the fast stable `qwen3-omni-flash` path. Fitness
  image Q&A and skeleton-based form-coach enrichment use `qwen-vl-max`. Generic
  fitness video fallback remains on the original model to avoid breaking video
  support, while AI Assistant training videos still use local Vision/rules.
- Diet image prompts were upgraded for mixed meals and Chinese meals: estimate
  staple carbs, protein foods, vegetables, oils/sauces, include portion
  reasoning in notes, self-check calories against 4/4/9 macros, and avoid
  returning 0 kcal for low-quality food photos unless the image is clearly not
  food.
- AI Assistant form analysis now attempts a hybrid enrichment pass after the
  local Vision/rule pipeline. The app renders several skeleton-only keyframes,
  sends only those skeleton images plus deterministic metrics/issues to
  `qwen-vl-max`, and asks for structured coach notes, selected keyframes,
  joint annotations, and 2-3 learnable cues. Raw training videos are not sent
  to the LLM in this path.
- Important UX invariant: skeleton-only keyframes are an internal LLM input,
  not the user's primary feedback image. AI Assistant must present the real
  video-frame feedback image (`feedbackImageData`) with green/red overlay,
  while using enrichment only for coach text/cues.
- The enrichment path is best-effort. If the visual model, JSON decoding, or
  annotation rendering fails, the user still receives the deterministic local
  coaching template and annotated video frame. This preserves offline/local
  utility and prevents cloud failures from destroying the core form-analysis
  result.
- `PoseOverlayRenderer` can render skeleton keyframes for internal AI context,
  but these images must not replace the user-facing real-frame overlay.
  Keyframes are selected from usable pose frames by time bucket and
  visible-joint completeness, not from raw last video frames.
- Vercel `/api/ai/chat` now declares `maxDuration: 60` because visual-model
  image/skeleton calls are slower than ordinary text streaming.
- Added bilingual strings for AI-coach enrichment notes and skeleton keyframe
  headers.
- Added a regression inside `form-coach-feedback-builder-tests` that decodes
  the cloud enrichment JSON shape (`coach_note`, `selected_frame_indexes`,
  `image_index`, `why_it_matters`, `how_to_fix`) and verifies AI cues can feed
  the local feedback builder without losing evidence/fix/drill structure.
- Post-release AI chat and media-upload hardening: the shared assistant input
  control now resets its `PhotosPicker` selection after each pick, shows a
  media-preparing spinner, disables send while media is still loading, and
  allows sending attachment-only messages. The keyboard accessory Done button
  was removed from the AI chat screens because it crowded the send control.
- Fitness and Diet AI assistants now expose explicit media-loading state and
  media error alerts instead of silently doing nothing when a selected
  photo/video fails to load or normalize.
- Fitness video/image sending now passes the current backend user/session into
  the media path, preserving form-analysis sync after local video analysis.
- Diet meal logging now auto-analyzes a newly saved meal entry when it has text
  or images, writes calories/protein/carbs/fat back to that meal, refreshes the
  daily summary, and shows the existing reconnect prompt if the cloud session
  is missing. The old "submit today's diet analysis" button remains as a
  fallback for full-day reanalysis.
- Form analysis now has a `FormAnalysisQualityGate` before scoring real
  extracted videos. Low-quality clips with too few usable frames, tiny bodies,
  weak confidence, or almost no joint motion are rejected with a filming
  instruction instead of receiving a misleading score.
- Added `form-analysis-quality-gate-tests` to protect this behavior: clean
  lifting motion passes, tiny creator/avatar-like frames and static clips fail.
  This is a trust hardening step, not a complete accuracy solution; the next
  product step is a real-video validation set and per-exercise rule calibration.
- AI language output is now driven by `AppLanguagePolicy.current`, which reads
  the app/system preferred language through `Locale.preferredLanguages`. The
  product no longer relies on Qwen/user input to guess the language.
- Training-plan generation, plan regeneration, training AI chat, Diet AI chat,
  Diet image analysis, Diet JSON nutrition analysis, and fitness media analysis
  now use language-specific system prompts. English prompts explicitly require
  English user-visible strings while preserving internal enum contracts such as
  workout `focus` and meal `mealType`.
- AI Assistant suggestion-only prompts, recent form-analysis context, plan
  regeneration results, and plan-edit command feedback now also follow the
  same language policy, preventing hidden Chinese prefixes from biasing English
  replies.
- `scripts/app-language-policy-tests.swift` now checks English plan examples,
  Diet analysis prompts, and fitness-media prompts so future changes do not
  quietly reintroduce Chinese prompt text into English mode.
- Diet entry deletion remains available through the visible Delete button and
  List swipe actions. TestFlight feedback clarified that swiping the meal title
  / text region works, while the photo strip is a horizontal scroll area and is
  not a reliable swipe-delete trigger.
- Diet meal cards now show per-entry calories, protein, carbs, and fat instead
  of hiding macros until the daily summary. Each scanned/added meal also has
  visible Edit and Delete controls in addition to swipe actions, so mistaken
  food photos can be removed without discovering hidden gestures.
- Editing or deleting a meal entry now recalculates the day summary, clears the
  summary when no nutrition remains, saves immediately, and notifies the Diet
  Widget refresh path.
- Workout cycle/date selection now advances on calendar-day boundaries rather
  than requiring a full 24 hours after plan creation. This prevents a plan made
  the previous evening from still showing the previous workout the next
  morning in both the app and widget.
- Added `FormCoachFeedbackBuilder`, a deterministic teaching layer for
  AI Assistant video analysis. It turns the local Vision + rule result into
  coach-style feedback: why the key frame was selected, what looked good,
  prioritized corrections, evidence, why the issue matters, how to fix it,
  a concrete drill, next-session focus, filming guidance, and the medical /
  training-scope limitation.
- AI Assistant now uses the new coaching text for video replies while keeping
  score, detected exercise, issues, and key metrics deterministic. LLMs may
  later explain the annotated key frame or generate correct-form examples, but
  must not replace the local score or detected issue list.
- Added `form-coach-feedback-builder-tests` and wired it into
  `scripts/run-form-analysis-tests.sh`; the test requires risky bench feedback
  to include evidence, why, fix, drill, next-session plan, and filming guidance,
  and verifies stable clips do not invent problems.
- TestFlight feedback on 2026-06-05 exposed a form-analysis trust issue: a
  bench video with a social-media ending screen selected the ending avatar as
  the annotated key frame. Added `PoseFrameQualityPolicy` and wired it into
  extraction and feedback planning so tiny/person-in-avatar frames are filtered
  before scoring and key-frame selection.
- Added a regression test that appends a 31.9s tiny outro pose to a valid bench
  sequence and proves the feedback key frame remains in the actual lift.
- Split WidgetKit into three addable widgets: Overview, Workout, and Nutrition.
  Workout and Diet are no longer mutually exclusive; users can add both from
  the iOS widget gallery. Nutrition now shows macro ratio based on 4/4/9 kcal
  shares instead of an equal-width decorative bar.
- Updated the Profile Apple Watch card with TestFlight-specific installation
  guidance: install the iPhone beta first, then use the Apple Watch button in
  the TestFlight app details Information section.
- Fixed the Chinese duplicate `sets` localization that rendered labels like
  `3 组数`; it now renders as `3 组`.
- Added an Apple Watch discovery/install/send card under Profile. The section
  is hidden for users without a paired Watch, explains the iPhone Watch App
  installation path when needed, and sends today's workout when installed.
- Removed the Watch card from Today Plan so the core training screen stays
  focused for users who do not use the companion.
- Added an opt-in Apple Health workout sync setting. Completing a full workout
  day on iPhone saves strength-workout type and estimated duration without
  inventing calories; Watch sessions remain the richer heart-rate path.
- Fixed unchecking an exercise so it removes today's corresponding log instead
  of leaving duplicates in Stats when the exercise is checked again.
- Diet AI now distinguishes a missing/expired session from provider failures:
  it asks the user to reconnect instead of falsely claiming a local AI result.
- Completed another bilingual pass across weekdays, AI response language,
  speech recognition, fallback plans, Profile data/editor, assistant controls,
  Diet labels, permission copy, and Widget workout metadata.
- The Watch companion now acknowledges workouts prepared from iPhone.
- Rebuilt the Widget around today's workout progress and next exercise.
  Small/medium/large layouts use system surfaces, support bilingual copy,
  retain the diet preference, and deep-link directly to Today Plan.
- Removed noisy PlanDashboard render logging and added deterministic Watch
  state and Widget presentation tests.
- Added standing overhead press as the fourth supported form-analysis movement,
  with automatic classification, independent rules, metrics, recommendations,
  localization, sync identifier, and good/risky score evidence.
- Automatic detection now rejects uncertain/unsupported movement instead of
  forcing every video into one of the supported labels.
- Annotated key frames now add issue callout labels connected to relevant
  joints, while retaining the red/green skeleton and result panel.
- Bounded pose extraction to 720 px and annotated feedback to 1600 px. The
  supplied 157 MB 4K video now completes the simulator UI flow in seconds
  instead of leaving the interface unresponsive.
- Diet Stats merges duplicate same-day data, excludes empty auto-created days,
  and uses 4/4/9 kcal shares for macro percentages.
- Backend-session changes now notify `AuthViewModel`, so an AI 401 immediately
  exposes the Apple reconnect state. Diet AI no longer labels every request
  failure as an image-processing failure.
- Added offline-first account snapshots for profile, workout plan/history, and
  diet records. SwiftData remains primary; first sync uploads meaningful local
  data or restores remote data onto a new empty device.
- Deployed authenticated `GET/PUT /api/cloud-snapshot` to production. Its table
  is created lazily after authentication, preventing a missed manual migration.
- Cloud snapshots exclude avatars, meal photos, raw videos, and chat media.
- Cloud snapshot digests are isolated per account, and retained local data is
  never uploaded automatically after switching to a different account.
- Added Apple Watch target with today's workout, current exercise, completion
  sync after all planned sets, 90-second rest timer, live heart rate, and
  HealthKit workout writing.
- Reduced normalized AI image payload ceiling from 1.8 MB to 1.1 MB after a
  physical-device console showed Vercel `FUNCTION_PAYLOAD_TOO_LARGE`; complex
  images now retry at smaller dimensions before failing.
- Fixed Reset Data so it requires confirmation, deletes every local product
  model including form analyses, and clears stale Watch workout context.
- Added a reachable confirmed Delete Account action. Authenticated deletion
  removes the backend user row and cascades cloud snapshots/form analyses
  before local data is cleared; backend failure preserves local data.

Completed in the current local milestone:

- Fitness and Diet AI images are normalized to bounded JPEG data before upload;
  attached images can be sent without typed text.
- Diet AI now distinguishes an expired cloud session and presents the Apple
  reconnect action instead of a generic failure.
- Video exercise selection defaults to local automatic detection among squat,
  deadlift, bench press, and standing overhead press, while retaining a manual
  override.
- New deterministic quality tests prove good fixtures score above risky
  fixtures for all four supported lifts.
- Deadlift back-position and bench elbow-angle rules were corrected after the
  new tests exposed that their previous good/risky fixtures scored identically.
- Annotated feedback now includes the exercise, score, key-frame time, and
  concise stable/attention result directly on the image.
- AI Assistant video feedback now explains auto-detection confidence, key
  metrics, why an all-green result can occur, and the analysis scope.
- Diet Stats no longer overlaps several area/line series. It now shows today's
  nutrition, macro distribution, one calorie trend, and recent records.
- AI Assistant is now the single user entry for training-video form analysis.
- Selecting a video exposes Auto plus all four supported movements and allows
  sending without a cloud session because pose analysis is local.
- Video analysis uses Apple Vision + local rules instead of uploading the video
  to the multimodal AI endpoint.
- Analysis replies include score, representative timestamp, issues, coaching,
  and an annotated key-frame image.
- Annotated feedback images show a green detected skeleton and red highlighted
  joints when an issue maps to a body area.
- Feedback images are uncropped in chat and open into a full-frame preview.
- Subsequent AI questions receive the most recent deterministic analysis as
  context, while being instructed not to contradict the local score/issues.
- Removed the duplicate form-analysis icon from training rows.
- Stats no longer presents the old volume/weight chart pile-up in the main
  flow. It now shows a concise overview, form progress, and recent training.
- Form-analysis results created in AI Assistant immediately appear in Stats.
- New video analyses no longer persist the full raw video in SwiftData chat
  history; only a compressed thumbnail and the analysis feedback are retained.

Completed in this milestone:

- Fixed the misleading Apple-login state. Local Apple identity and usable
  backend session are now separate states.
- AI chat blocks sending when the cloud session is missing and opens Apple
  reconnect UI instead of persisting a misleading login error.
- AI chat initially scrolls to the newest message.
- Removed the entire developer backend/session editor from Profile.
- Fixed Stats data ownership: overall totals and weight trends no longer break
  when filtering one exercise.
- Stats volume trend is aggregated by day; empty state is no longer duplicated.
- Added a reachable form-analysis button for supported squat, deadlift, and
  bench-press exercises.
- Added `FormAnalysisRecord` to the app SwiftData schema.
- Fixed immediate form-analysis sync to use the real Apple session and the
  correct `/api/form-analyses` endpoint.
- Secured `/api/form-analyses` with real FitGenius session verification.
- Restored all 70 required form-coach localization keys in Chinese and English.
- Created `docs/product-quality-plan.md` to manage work as a complete product.

## Production Backend Status

Production URL: `https://fitgenius-ashen.vercel.app`

Verified live on 2026-06-04:

- `GET /api/health` returned HTTP 200.
- Unauthenticated and invalid-session form-analysis requests returned HTTP 401.
- Authenticated `POST /api/ai/chat` returned HTTP 200 and a real Qwen response.
- The streaming AI path used by the iOS app returned valid SSE chunks ending in
  `[DONE]`.
- Authenticated `POST /api/form-analyses` returned HTTP 200 with
  `mode: stored`; the temporary Neon probe record and probe user were deleted.
- Production Vercel environment values were repaired for `DATABASE_URL`,
  `ALIYUN_API_KEY`, `SESSION_SECRET`, `APPLE_BUNDLE_ID`, and
  `BACKEND_PUBLIC_URL`.
- Deployment `dpl_ENLsB96UFzENTjYu3JDbxY5p4zrf` is live on
  `https://fitgenius-ashen.vercel.app`.
- `GET /api/cloud-snapshot` returns HTTP 401 without a session and with an
  invalid session. A real Apple-authenticated GET/PUT remains to be accepted
  from the app.

Important: the production `SESSION_SECRET` changed during repair. Existing
phone sessions are invalid. Users with the old local Apple identity must use the
new reconnect prompt once to receive a new FitGenius cloud session.

## Latest Validation

### 2026-10-03: Common-exercise batch

- All 24 cloud MP4 downloads byte-match their local encoded assets. ffprobe
  confirms H.264 video plus AAC audio, expected excerpt durations and the
  existing 20 MB asset limit. URLs are stable Hosting paths, not expiring Douyin
  CDN addresses.
- `tutorial-source-coverage.mjs`: 1324 templates, 49 tracked source videos,
  15 downloaded originals, 24 hosted development clips, zero licensed clips.
- `tutorial-catalog-audit-tests.mjs`: PASS. The compiled Swift remote-catalog
  regression suite passes with `--live`: the cloud manifest equals the local
  manifest, all clips decode, and Debug/Release filtering remains correct.
- Corrected the existing `0586` Chinese name from supine to prone leg curl;
  canonical GIF and both existing instruction languages already specify prone.
  The updated unsigned simulator build passes. The existing extension/main
  CFBundleVersion mismatch warning remains; no signing/install was performed.
  New physical-device playback/comparison acceptance is still required.

### 2026-10-03: cloud tutorials

- Remote repository regression tests pass: valid update/cache, bad JSON/schema/status,
  insecure source rejection, last-good preservation, empty remote removal, and
  Debug/Release filtering. Existing tutorial, comparison/catalog audit checks pass.
- Unsigned iOS Simulator build passed with the remote store and shared detail.
- CloudBase authorization refreshed by the owner; scoped Hosting deployment
  succeeded. HTTPS catalog and development MP4 delivery were checked separately.
- Tutorial video-cache tests pass for file reuse, MIME/signature and status
  rejection; a real CloudBase MP4 was downloaded and its cached size verified.
- New bilingual loading/failure strings pass the localization check. Final
  unsigned simulator build includes the cache-based player and passes.
- This does not prove physical-device playback or exhaustive source coverage.

### 2026-09-21: progressive entry and plan proposals

- Current-plan policy tests pass for linked-plan priority, newest standalone
  fallback, and empty-store behavior.
- Plan proposal tests pass for valid edits, set ranges, rest-day protection,
  missing/ambiguous targets, replacement continuity, and replacement rest-day
  checks.
- The full unsigned iOS Simulator build succeeds with Xcode 27 / iOS 27 SDK.
- Source audit finds no root onboarding gate and no local regex intent
  classifier. Plan changes are written only from explicit apply actions after
  proposal validation.

### 2026-09-20: unified exercise-learning entry

- The updated `exercise-tutorial-catalog-tests` first failed because the
  library had no persistent `TextField`; after the shared-entry correction it
  passes and also guards against reintroducing a plan-only tutorial dependency.
- `video-comparison-timeline-tests`, `tutorial-catalog-audit-tests`, catalog
  audit, localization checks, and `git diff --check` pass.
- Xcode 27 iOS Simulator build passes. The resulting Debug app contains both
  `tutorial_clips.json` and `tan-dumbbell-lateral-raise.mp4`.
- Xcode 27 signed physical-device build for iOS 27 passes. Version 1.5.1
  (build 20260804) was installed on `宝剑的iPhone`; automated launch was
  denied only because the phone had returned to the lock screen, so the final
  on-screen interaction check still requires an unlocked device.

### 2026-09-19: exercise-learning vertical slice

- `exercise-tutorial-catalog-tests`: PASS.
- `video-comparison-timeline-tests`: PASS.
- `tutorial-catalog-audit-tests`: PASS.
- Catalog audit: PASS for one mapped clip, one template, and no missing local
  playback reference in the development workspace.
- Both localization files pass `plutil -lint`; the project localization check
  passes.
- A whole-target `swiftc -typecheck` against the generated FitGenius source
  list passes. The only warning is the existing deprecated HealthKit workout
  initializer.
- Full `xcodebuild` is currently blocked on this Mac because the matching iOS
  Simulator/platform runtime is not installed. This is an environment gate,
  so the feature still needs an installed-runtime/physical-iPhone visual and
  playback acceptance pass.

### 2026-08-03: conversation-session pass

- `chat-session-policy-tests`: PASS.
- `scripts/check-localization.sh`: PASS; both `Localizable.strings` files pass
  `plutil -lint`.
- iPhone 17 Pro (iOS 26.1) Simulator build passed with
  `CODE_SIGNING_ALLOWED=NO`.
- The newly built app installed and launched on the existing Simulator data
  store without a SwiftData migration error. A delayed screenshot reached the
  normal training home. Computer-use automation disconnected before it could
  tap the AI-history controls, so visible button interactions still require a
  manual Simulator or physical-iPhone acceptance pass.
- `git diff --check`: clean.

### 2026-08-03: health-AI activation and layout pass

- `assistant-health-context-tests`: PASS.
- `scripts/check-localization.sh`: PASS; both localization files pass
  `plutil -lint`.
- iPhone 17 Pro (iOS 26.1) Simulator build passed with
  `CODE_SIGNING_ALLOWED=NO`. The non-blocking Xcode DVT build-number warning
  remains unchanged.
- Physical-iPhone acceptance still needs to confirm the actual Apple Health
  prompt and the resulting banner state with the user's data.

- 2026-08-02 health-report hardening:
  - `recovery-insight-engine-tests: PASS`, including the new sleep-only
    insufficient-data regression.
  - `health-report-week-range-tests: PASS`, proving Sunday noon is in the
    current week and next Monday midnight is excluded.
  - `scripts/check-localization.sh`: PASS; both localization files pass
    `plutil -lint`.
  - iPhone 17 Pro iOS 26.1 Simulator build passed with
    `CODE_SIGNING_ALLOWED=NO`; only the pre-existing Xcode DVT build-number
    warning remains.
  - `git diff --check`: clean.
  - Simulator retained prior onboarding state after reinstall, so the duplicate
    keyboard-toolbar visual fix is build-verified but still needs one clean
    install / physical-iPhone visual acceptance pass.

- 2026-06-22 MiniMax migration validation so far:
  - `npm run test:backend` passed: 26 tests, including provider selection,
    legacy/new model alias mapping, multimodal passthrough, streaming EOF,
    missing credentials, upstream errors, and Aliyun rollback.
  - `hybrid-ai-routing-tests` passed with distinct provider-neutral aliases for
    text, image, and video requests.
  - Full `scripts/predeploy-check.sh` passed: backend 26/26, all iOS script
    tests, Widget/Watch regressions, localization, and deployable secret scan.
  - Production deployment completed successfully; `/api/health` returned 200
    and `/api/ai/chat` preserved its 401 authentication boundary.
  - Direct MiniMax probes passed for non-streaming text, image, video, and SSE
    streaming. `reasoning_split: true` keeps reasoning outside visible content.
  - Xcode shell build and XcodeBuildMCP runtime launch are currently blocked by
    a missing/unavailable iOS 26.1 Simulator Runtime on this Mac. This is a
    local Xcode component issue, not a compiler diagnostic from the app code.

- 2026-06-11 regression fix validation:
  - Added `AIModelRouting` and `FormAnalysisChatPresentation` to make the two
    corrected behaviors explicit: Diet image analysis stays on
    `qwen3-omni-flash`, and AI Assistant presents the real video-frame feedback
    image instead of skeleton-only enrichment art.
  - Added `hybrid-ai-routing-tests`; it passed and is wired into
    `scripts/run-form-analysis-tests.sh`.
  - `scripts/run-form-analysis-tests.sh` passed.
  - `scripts/predeploy-check.sh` passed: backend 25/25, iOS script tests,
    localization check, deployable-file secret scan, and local env reminder.
  - XcodeBuildMCP build/run on iPhone 17 Pro simulator succeeded with zero
    errors after the regression fix. One existing HealthKit deprecation warning
    remains unrelated to this change.
- 2026-06-07 hybrid AI upgrade validation:
  - Official Aliyun/DashScope OpenAI-compatible VL documentation was checked;
    `qwen-vl-max` is listed as a valid vision model name for compatible chat
    completions.
  - `npm run test:backend` passed: 25/25 backend tests.
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild
    -project FitGenius.xcodeproj -scheme FitGenius -destination
    'generic/platform=iOS Simulator' -derivedDataPath
    /tmp/FitGeniusDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded with
    the iPhone app, Widget extension, and Watch app embedded.
  - XcodeBuildMCP build/run on iPhone 17 Pro simulator succeeded with zero
    warnings and zero errors, launching bundle `com.swordingk.fitgenius`.
  - XcodeBuildMCP runtime snapshots verified startup in Diet mode, Diet AI
    Assistant controls, keyboard-visible send button after typing, switch to
    Training mode, and Fitness AI Assistant controls.
  - `scripts/predeploy-check.sh` passed with the Xcode toolchain workaround:
    backend 25/25, iOS script tests, localization check, deployable-file secret
    scan, and deployment env reminder. Missing env values are expected in local
    shell unless running with `--require-env`.
  - After adding the hybrid-enrichment JSON regression, both
    `scripts/run-form-analysis-tests.sh` and `scripts/predeploy-check.sh`
    passed again.
- `scripts/predeploy-check.sh` passed after the post-release AI media, Diet
  auto-analysis, and form-quality-gate hardening. Because the local `swiftc`
  shim under `.mavis` fails in the Chinese project path, this was run with the
  Xcode toolchain first in `PATH`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`,
  `SDKROOT` set to the macOS SDK, and UTF-8 locale.
- XcodeBuildMCP iPhone simulator build/run succeeded with zero warnings and
  zero errors after the assistant media, Diet auto-analysis, and form-quality
  changes.
- `scripts/run-form-analysis-tests.sh` passed with the new
  `form-analysis-quality-gate-tests` regression.
- `swiftc FitGenius/Services/AppLanguagePolicy.swift scripts/app-language-policy-tests.swift`
  passed after the AI language-policy hardening. The tests now cover both
  Simplified Chinese and English branches and ensure English mode uses English
  examples/prompts for workout plans, Diet analysis, and fitness media.
- `scripts/predeploy-check.sh` passed after the AI language-policy hardening:
  backend 25/25, all iOS script tests, localization check, deployable-file
  secret scan, and app language policy regression tests.
- XcodeBuildMCP iPhone simulator build/run succeeded with zero warnings and
  zero errors after the AIService and AIAssistantViewModel language changes.
- `scripts/predeploy-check.sh` passed after the Diet per-meal macro/delete
  changes and calendar-day workout-cycle fix. The suite includes the new
  `Workout cycle calculator tests passed` regression.
- XcodeBuildMCP build/run succeeded with zero warnings and zero errors after
  the Diet UI and workout-cycle changes. Simulator snapshot verified the
  training date is now `6/5`; the local demo plan still labels that fixture as
  chest, so content matching must be checked against a real user plan.
- `scripts/run-form-analysis-tests.sh` passed after the coach-feedback builder
  changes, including the new teaching-feedback regression.
- `scripts/predeploy-check.sh` passed after the form-frame filter and Widget
  changes: backend 25/25, all iOS script tests, localization, and secret scan.
- New `pose-frame-quality-policy-tests` passed, covering the 31.9s social-media
  outro regression from the TestFlight screenshots.
- XcodeBuildMCP build/run succeeded with zero warnings and zero errors after
  the Watch TestFlight hint and three-widget bundle changes.
- Latest generic iOS Simulator build succeeded with iPhone, Widget, and Watch
  embedded after the HealthKit and system-language changes.
- English simulator verified `Thu` instead of the previously hard-coded Chinese
  weekday, no Watch promotion on Today Plan, and no Watch Profile section when
  a Watch is not paired.
- English simulator verified localized Profile measurements, AI Assistant input
  placeholder, and Clear/Suggestion/Edit menu actions. Existing stored Chinese
  chat messages are intentionally preserved as user history.
- Simulator verified Diet AI missing-session behavior leaves the meal record
  unchanged and offers Apple reconnect.
- Simulator verified uncheck/recheck keeps Stats exercise count stable instead
  of creating a duplicate log.
- Generic iOS Simulator build succeeded with the iPhone, Widget, and Watch
  targets embedded and validated.
- XcodeBuildMCP build/run succeeded with zero diagnostics. Simulator screenshot
  verified the Today Plan Apple Watch launcher and sent-workout action.
- Opening `fitgenius://today` returned from Profile to the training-plan tab.
- Simulator Profile verified that the paired-Watch discovery card appears with
  the sent state; code hides the entire section when no Watch is paired.
- Watch preparation-state and Widget presentation tests passed, including
  paired/install guidance, queued preparation, progress, and next-exercise
  selection.
- `npm run test:backend`: 25/25 passing, including authenticated account
  deletion, cloud snapshot validation, lazy schema creation/retry, and the
  users-table foreign key regression.
- Production deployment completed and `/api/health` returned HTTP 200.
- Cloud snapshot missing/invalid authorization both returned HTTP 401.
- Account deletion missing/invalid authorization both returned HTTP 401.
- Localization check passed: 70/70 required keys in Chinese and English.
- `git diff --check`: clean.
- watchOS 26.1 simulator runtime installed successfully.
- XcodeBuildMCP iPhone build/run succeeded with zero diagnostics after embedding
  the Watch app.
- Latest XcodeBuildMCP iPhone build/run succeeded with zero warnings and zero
  errors after the form-coach/Diet Stats changes.
- Latest form-analysis suite passes, including unsupported-motion rejection,
  overhead-press scoring, feedback callouts, bounded 4K processing, same-day
  Diet Stats aggregation, and backend-session notifications.
- `scripts/predeploy-check.sh` passed: backend 25/25, all iOS script tests,
  localization, and deployable-file secret scan.
- Simulator verified:
  - the selector shows Auto, Squat, Deadlift, Bench Press, and Standing
    Overhead Press without a cramped segmented control;
  - the supplied launch video returns annotated feedback in seconds;
  - the feedback image contains a red issue callout connected to the elbow;
  - an empty auto-created MealDay displays `0 days logged` and the real empty
    state instead of a fake `0 kcal` recent record.
- Watch simulator build, installation, and launch succeeded. After the iPhone
  app relaunched, WatchConnectivity delivered today's workout and the Watch UI
  displayed the current deadlift, `3 x 5`, `100 kg`, and `0 / 3` completed sets.

- XcodeBuildMCP simulator smoke test:
  - automatic selection classified the supplied launch video as bench press at
    95% confidence;
  - the result returned 76 points for the deterministic risky fixture, a
    specific elbow-angle issue, key metrics, and a red highlighted region;
  - Diet Stats rendered the simplified layout without overlapping charts;
  - Diet AI displayed the Apple reconnect banner for the expired session.
- Deterministic score evidence:
  - squat good 96 vs risky 46;
  - deadlift good 96 vs risky 66;
  - bench press good 96 vs risky 76.
- Generic iOS Simulator build: succeeded after the latest UI changes.
- `scripts/run-form-analysis-tests.sh`: all scripts passing.
- `npm run test:backend`: 15/15 passing, including multimodal forwarding.
- Real provider image acceptance and real-device Vision remain physical-iPhone
  acceptance steps.
- XcodeBuildMCP end-to-end simulator smoke test:
  - AI Assistant loaded the supplied bench video;
  - exercise selector defaulted to bench press;
  - send returned a 96-point result and annotated feedback frame;
  - annotated image appeared uncropped and opened as a full-frame preview;
  - Stats displayed the new analysis record and form-progress summary;
  - training rows no longer displayed duplicate analysis buttons.
- The current simulator does not support the real Apple Vision request. A
  DEBUG-only fixture fallback was used only to validate UI and drawing. Release
  builds never use that fallback.
- Generic iOS Simulator build: succeeded.
- `scripts/run-form-analysis-tests.sh`: 6/6 binaries passing, including the new
  representative-frame and issue-highlight planner test.
- `npm run test:backend`: 15/15 passing.
- `git diff --check`: clean.

- XcodeBuildMCP simulator build and run: succeeded with zero diagnostics.
- Simulator UI:
  - form-analysis button appeared for the three exercises in the then-current
    demo plan;
  - form-analysis sheet opens with localized Chinese content;
  - AI chat opens at the newest message;
  - Profile has no backend debug section;
  - Stats empty state is clean and localized.
- `npm run test:backend`: 15/15 passing.
- `scripts/run-form-analysis-tests.sh`: 5/5 binaries passing.
- `scripts/check-localization.sh`: 70/70 required keys present in both languages.
- Live production backend: AI request and Neon form-analysis storage verified.

## Manual Step Needed From User

On a physical iPhone build:

- In the exercise library, confirm the search field is visible without a
  pull-down gesture. Search `哑铃侧平举`, open the result directly, and confirm
  the Tan Sir tutorial can play and reach the user-video comparison picker.
- Open one template-backed plan exercise and confirm it shows the same learning
  content plus prescription; open a custom/unmatched action and confirm it
  remains on the compact fallback.

0. Accept the latest Apple Developer Program License Agreement, then enable
   HealthKit for the iPhone and Watch App IDs/provisioning profiles if Xcode
   still reports that the capability is missing.
1. Open **My**.
2. Tap the Apple reconnect prompt or log in with Apple.
3. Open AI Assistant, choose a 10-30 second squat/deadlift/bench/standing
   overhead-press video, leave Auto selected, and tap Send.
4. Confirm that the returned skeleton follows the real body, the key frame is
   useful, and any red highlight matches the detected issue.
5. After this build is installed on two Apple-authenticated devices, edit a
   workout or diet record on one device and confirm the other restores it.
6. Pair an Apple Watch and accept Health access, then verify heart rate,
   completion sync, rest timer, and saved HealthKit workout.
7. In both Fitness AI and Diet AI, upload one photo after reconnecting Apple
   login and confirm the real multimodal response succeeds.

This is required because Apple authorization UI and real-device Vision behavior
cannot be fully accepted in Simulator.

## Next Recommended Work

Cloud tutorial research continuation:

- First verify the common-exercise batch using `docs/tutorial-batch-acceptance.md`
  on the current Debug build. Restart the App to bypass the in-memory six-hour
  refresh throttle, then open an action detail to load the published manifest.

- Continue the official profile beyond the 49 recorded teaching sources; review
  long private-training/follow-along videos for exercise-specific variants.
- Use `node scripts/tutorial-source-coverage.mjs` for counts or `--json` for all
  1324 exercise rows. A blank candidate list means unreviewed, never confirmed absent.
- Review and cut the downloaded pulldown original by grip variant before
  publishing; its visible chapters are recorded in the source inventory.
- Verify cloud-loaded Debug playback and Photos comparison on the owner's iPhone.
  Keep development media hidden from Release; approved production media may be
  added with stable HTTPS URLs and `licensed` status without another App release
  after this loader version has shipped. Migrate the cloud JSON index to a database
  API when adding an editing/admin workflow; binary videos remain in object storage.

Progressive-entry / plan-copilot acceptance:

- On a clean physical-device install, verify the empty dashboard, manual
  day/action creation, and general AI text questions without a Profile.
- Generate a personalized candidate after adding a manual action; cancel once
  and confirm the old plan is unchanged, then regenerate and explicitly apply.
- With real provider responses, verify one local action edit and one full split
  change both show previews, and malformed responses leave SwiftData untouched.

Exercise-learning next slice:

- Install the matching iOS runtime or use a physical iPhone, then verify row
  navigation, GIF rendering, Photos permission, local tutorial playback,
  synchronized scrubbing, manual offsets, rotation, and background pausing.
- Review the queued Tan Sir inventory, cut one clean 10-20 second teaching
  segment per matched exercise, and record the exact template ID and timestamps.
- Before distribution, obtain permission and move approved clips to object
  storage/CDN; replace development-only URLs with hosted licensed assets.

1. On a clean iPhone install, complete onboarding with a numeric keyboard and
   confirm exactly one Done control is visible and the keyboard dismisses when
   Next is tapped.
2. In both AI Assistant modes, verify New Conversation opens a clean welcome
   thread, Chat History can reopen the earlier thread, individual swipe-delete
   deletes only that thread, and a new message does not receive context from a
   different conversation.
3. In Fitness AI, use the context banner to open Profile, enable AI health
   summaries, authorize Body Report data, then return and confirm the banner
   changes to the ready state after refresh.
4. Authorize Apple Health with a Watch user and verify the new insufficient-data
   state first, then verify that sleep + HRV/resting-heart-rate + training data
   produces a transparent recommendation with evidence. Do not market the
   score as medical or clinically validated.
5. Advanced vitals are currently displayed but not used in the score. Do not
   market the readiness score as clinical or medical guidance.
6. Reconnect Apple login on a physical device and test Diet image recognition
   with 5-10 real meals: mixed Chinese meal, rice/noodles, meat + vegetables,
   drink/snack, and a deliberately poor photo. Confirm per-meal calories and
   macros are written back and that notes explain the estimate.
7. Test AI Assistant form coaching on physical device with at least 3 clips per
   supported lift: clean rep, obvious mistake, and poor filming/angle. Confirm
   the selected skeleton frame belongs to the lift, not platform intro/outro
   frames, and that AI cues do not contradict local score/issues.
8. Build a small labeled validation set before expanding beyond squat,
   deadlift, bench press, and standing overhead press. Threshold tuning needs
   real examples, not synthetic fixtures.
9. Run authenticated cloud-snapshot GET/PUT acceptance from the app.
10. Complete the remaining bilingual UX audit and prepare a TestFlight release
   candidate only after real-device Diet image and form-coach acceptance pass.

## Risks

- Do not reset or overwrite work that is not understood.
- Do not rotate or print production secrets. The current production backend is
  Tencent CloudBase; older Vercel files in the repo are historical and are not
  the source of truth for production behavior.
- Do not reintroduce an AI provider key into the iOS app or GitHub.
- Do not treat a successful build as proof of Apple login or Vision on a
  physical device.
- The simulator annotated frame is UI proof only; its pose comes from a
  DEBUG-only fixture because Vision is unavailable in this simulator runtime.
