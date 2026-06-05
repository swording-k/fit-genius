# FitGenius Agent Handoff

Last updated: 2026-06-05 11:20 Asia/Shanghai

## Read First

1. `AGENTS.md`
2. `docs/form-coach-roadmap.md`
3. `docs/product-quality-plan.md`
4. `docs/agent-handoff.md`

## Current Status

The cloud-sync and Apple Watch milestone is committed at `bafaf2e`, the
form-coach product-quality milestone is committed at `ab59258`, and the
form-keyframe / Widget TestFlight fix is committed at `e715c2d`. The current
local milestone upgrades AI Assistant video-analysis copy from a terse
detection report into structured coaching feedback.

Latest milestone:

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

1. Run authenticated cloud-snapshot GET/PUT acceptance from the app.
2. Run physical-device acceptance for normalized fitness/diet images and real
   Vision joints using several camera angles.
3. Tune thresholds using a labeled real-video set before claiming broader
   exercise support.
4. Complete the remaining bilingual UX audit and prepare a TestFlight release
   candidate.

## Risks

- Do not reset or overwrite work that is not understood.
- Do not rotate or print production secrets. They exist only in Vercel.
- Do not reintroduce an AI provider key into the iOS app or GitHub.
- Do not treat a successful build as proof of Apple login or Vision on a
  physical device.
- The simulator annotated frame is UI proof only; its pose comes from a
  DEBUG-only fixture because Vision is unavailable in this simulator runtime.
