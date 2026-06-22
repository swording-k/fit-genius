# FitGenius Agent Handoff

Last updated: 2026-06-22 Asia/Shanghai

## Read First

1. `AGENTS.md`
2. `docs/form-coach-roadmap.md`
3. `docs/product-quality-plan.md`
4. `docs/agent-handoff.md`

## Current Status

MiniMax provider migration is in progress on 2026-06-22:

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

- `FitGenius.xcodeproj/project.pbxproj` has a pre-existing iOS version-number
  change (`MARKETING_VERSION` 1.1 -> 1.2, `CURRENT_PROJECT_VERSION` 1 -> 1.1).
- `FitGenius.xcodeproj/xcuserdata/.../xcschememanagement.plist` has a
  pre-existing Xcode scheme-order change for the Watch scheme.
- `HYBRID_AI_UPGRADE_PLAN.md` is an untracked local planning file.
- Do not revert or fold those into Android work unless the user explicitly asks.

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

1. Reconnect Apple login on a physical device and test Diet image recognition
   with 5-10 real meals: mixed Chinese meal, rice/noodles, meat + vegetables,
   drink/snack, and a deliberately poor photo. Confirm per-meal calories and
   macros are written back and that notes explain the estimate.
2. Test AI Assistant form coaching on physical device with at least 3 clips per
   supported lift: clean rep, obvious mistake, and poor filming/angle. Confirm
   the selected skeleton frame belongs to the lift, not platform intro/outro
   frames, and that AI cues do not contradict local score/issues.
3. Build a small labeled validation set before expanding beyond squat,
   deadlift, bench press, and standing overhead press. Threshold tuning needs
   real examples, not synthetic fixtures.
4. Run authenticated cloud-snapshot GET/PUT acceptance from the app.
5. Complete the remaining bilingual UX audit and prepare a TestFlight release
   candidate only after real-device Diet image and form-coach acceptance pass.

## Risks

- Do not reset or overwrite work that is not understood.
- Do not rotate or print production secrets. They exist only in Vercel.
- Do not reintroduce an AI provider key into the iOS app or GitHub.
- Do not treat a successful build as proof of Apple login or Vision on a
  physical device.
- The simulator annotated frame is UI proof only; its pose comes from a
  DEBUG-only fixture because Vision is unavailable in this simulator runtime.
