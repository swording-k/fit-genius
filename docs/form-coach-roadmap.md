# FitGenius Form Coach Roadmap

Last updated: 2026-06-05

## Product Vision

FitGenius should become a personalized strength-training coach, not just a workout-plan generator. The long-term product loop is:

1. Generate a personalized training plan.
2. Guide daily gym training.
3. Analyze user-uploaded lifting videos.
4. Give specific coaching feedback.
5. Save form-quality history.
6. Suggest safe plan adjustments.
7. Expand to more training profiles such as bodybuilding, powerlifting, basketball strength training, and general performance training.

The key product advantage should be the closed loop between training plan, video form analysis, and plan adjustment.

### Current Product Focus

FitGenius is narrowing the next release around one visible user pain point:
understanding what is wrong in a lifting video and what to change next time.

The AI Assistant becomes the unified coaching surface:

1. User selects a training video in AI Assistant; FitGenius auto-detects the
   supported exercise and allows a manual override.
2. Apple Vision extracts pose joints locally.
3. FitGenius rules produce the score and issues.
4. FitGenius returns an annotated representative frame plus structured
   coaching: evidence, why it matters, how to fix it, a drill, and the next
   training focus.
5. AI can explain the annotated frame, answer follow-up questions, or generate
   correct-form teaching examples, but it must not invent or replace the local
   score, exercise type, or detected issue list.

Pre-release polish on 2026-06-23 also makes onboarding more personalized:
Strength and Sport Performance are first-class goals, and notes explicitly
invite sport-specific needs such as basketball, competition prep, posture,
recovery, weekly availability, and target lifts. Initial and regenerated plan
prompts must treat those inputs as core constraints rather than falling back to
generic fat-loss or bodybuilding templates.

Training plans and Stats support this loop. The first Watch workout companion
is now implemented, while Android/Huawei and broad exercise expansion remain
paused until this experience is useful.

TestFlight feedback from 2026-06-05 tightened the MVP bar: annotated form
feedback must never select social-media intro/outro frames or tiny creator
avatars as the key frame. Pose frames now need to pass a body-size/quality gate
before scoring or feedback-frame selection.

The same feedback clarified the product bar for coaching depth: a video reply
must teach the user what to change, not merely report a score. AI Assistant
video feedback now needs to explain the selected key frame, visible evidence,
priority corrections, concrete cues, practice drills, next-session focus, and
better filming guidance. Future multimodal LLM work should enhance the
teaching layer and correct-form examples while preserving deterministic local
rules as the source of truth.

## Technical Direction

The iOS MVP uses Apple Vision for local human pose detection. Vision only extracts body keypoints; FitGenius owns the exercise rules and coaching logic.

To avoid locking the product into Apple-only APIs, Vision output is converted into platform-neutral models:

- `PoseFrame`
- `JointPoint`
- `JointName`
- `FormMetric`
- `FormIssue`

Future Android/Huawei clients should generate the same pose format using MediaPipe Pose Landmarker or vendor-specific pose APIs. The rule engine should stay independent from Apple Vision types.

Localization principle:

- FitGenius should keep Chinese as the primary quality baseline while also supporting English users.
- New user-facing strings must be added to both `zh-Hans.lproj/Localizable.strings` and `en.lproj/Localizable.strings`.
- SwiftUI variable string keys must be explicitly localized instead of relying on automatic literal localization.
- Feature work should include a quick localization pass so the app follows the system language and does not expose raw keys.

Agent handoff principle:

- Development progress must not live only in chat history.
- Future agents should read `AGENTS.md`, this roadmap, and `docs/agent-handoff.md` before editing.
- Every meaningful milestone should update `docs/agent-handoff.md` with current status, latest validation, and next recommended work.
- Route, scope, or acceptance-criteria changes should also update this roadmap.

## Phased Plan

### Phase 0: Stable Baseline

- Treat local repository state as the latest product baseline.
- Clean up exposed API keys from app bundle, project settings, and shared schemes.
- Keep App Store compliance work such as privacy manifest, data export/import, account deletion, and data-source references.
- Verify Xcode build and simulator launch.
- Push the cleaned baseline to GitHub after review.

### Phase 1: iOS Form Analysis MVP

Supported exercises:

- Squat
- Deadlift
- Bench press
- Standing overhead press

The release intentionally keeps a small supported set. More movements
must be added one at a time with an explicit rule set, good/risky fixtures, and
real-video acceptance evidence. A multimodal model may help describe a video,
but it must not silently invent the deterministic exercise type, score, or
issue list.

User flow:

1. User opens a workout exercise.
2. User taps form analysis.
3. User selects or records a 10-30 second training video.
4. App samples frames and extracts body pose keypoints locally.
5. Local rule engine calculates score, issues, metrics, and recommendation.
6. Result is saved as form analysis history.
7. User can apply recommendation back to the training plan.

MVP output:

- Score from 0-100.
- Up to 3 key issues.
- Recognition quality metrics.
- Basic exercise metrics.
- Plain-language recommendation.

### Phase 2: Backend Product Foundation

Use Vercel + Neon Postgres in the same GitHub repository as a monorepo.

Backend responsibilities:

- Apple Sign in token exchange.
- User session management.
- Cloud sync for profile, workout plan, diet, chat, and form analysis records.
- AI proxy so provider API keys are never stored in the iOS app bundle.
- Subscription entitlement schema and API reserved for future paid features.

The iOS app remains offline-capable. Login and sync enhance the product but should not block local training usage.

**Phase 2 status (production backend verified 2026-06-04)**:
Vercel, Neon, Apple-session verification, AI proxy, and form-analysis storage
are wired. A live authenticated AI request returned a real provider response,
and a live authenticated form-analysis request returned `mode: stored` from
Neon. Account cloud snapshots for profile, workout plan/history, and diet are
implemented and deployed. They remain offline-first and intentionally exclude
large media and chat history. Authenticated account deletion removes all cloud
rows through database cascades. Existing phone sessions must reconnect once
because the production session secret was repaired.

### Phase 3: Apple Watch Experience

The first watchOS experience should support training-session assistance, not video analysis:

- Today's workout.
- Current exercise.
- Set/rest timer.
- Mark set or exercise complete.
- Heart-rate display.
- HealthKit workout writing.
- Profile-only discovery, install guidance, and today's-workout send action,
  shown only when an Apple Watch is paired.

Video analysis stays on iPhone.

### Phase 4: Android and Huawei Expansion

Only start after the iOS form-analysis MVP proves user value.

Cross-platform strategy:

- Reuse the backend, training models, and pose schema.
- Use MediaPipe or platform pose APIs to generate `PoseFrame`.
- Keep exercise rules and coaching logic aligned across clients.

Phase 4 kickoff note (2026-06-12):

- The Android client starts as a native Kotlin + Jetpack Compose app under
  `android/`, isolated from the current iOS project.
- First Android build targets core product parity: training, diet, AI Assistant,
  and form-coach structure. Android widgets, watch features, store release
  automation, and HarmonyOS NEXT native work remain deferred.
- The first acceptance target is a locally buildable debug APK, not broad
  app-store distribution.

## Current Implementation Status (verified 2026-06-04)

Implemented:

- AI Assistant unified form-analysis flow for squat, deadlift, bench press, and
  standing overhead press. Unsupported/uncertain motion is rejected instead of
  being forced into a misleading label.
- Platform-neutral pose models, Apple Vision extraction, local rule engine,
  local history persistence, recommendation application, and cloud sync.
- Representative-frame planning, skeleton/issue overlay rendering, tappable
  annotated feedback, issue callout labels, recent-analysis AI follow-up
  context, and form-progress Stats.
- Apple login exchange, FitGenius sessions, Vercel AI proxy, and Neon storage.
- Offline training/diet baseline, Widget, compliance screens, and bilingual
  localization.
- Product stabilization for AI connection state, newest-message chat opening,
  Profile debug-control removal, and Stats filtering/empty states.

Implemented locally, pending paired-device acceptance:

- Apple Watch companion for today's workout, current exercise, completion,
  per-set progress, rest timer, live heart rate, and HealthKit workout writing.
- Profile-only iPhone Watch discovery and workout preparation flow, plus a redesigned
  Widget set with separate Overview, Workout, and Nutrition widgets. Users can
  place training and diet widgets on the same Home Screen.
- Optional iPhone HealthKit workout writing when a full training day becomes
  complete. It records strength-workout type and duration without inventing
  sensor-derived calories.

Not started:

- Android/Huawei clients.
- Subscription and billing.

## Validation Log

Last verified on 2026-06-04:

- Generic iOS Simulator build and XcodeBuildMCP build/run succeeded.
- Simulator UI verified the form-analysis entry, newest-message AI chat,
  debug-free Profile, and localized Stats empty state.
- Diet Stats now merges duplicate same-day records, excludes empty auto-created
  days, and calculates macro distribution from 4/4/9 kcal shares.
- 4K pose extraction is bounded to 720 px frames and annotated chat feedback to
  1600 px, preventing long UI stalls on the supplied 157 MB video.
- `scripts/run-form-analysis-tests.sh`: 5/5 binaries passed.
- `npm run test:backend`: 15/15 tests passed.
- `scripts/check-localization.sh`: 70/70 required form-coach keys passed.
- Production AI non-streaming and streaming requests returned real Qwen output.
- On 2026-06-22, a provider-neutral backend adapter was added for a staged
  MiniMax migration. It accepts both released-build Qwen model names and new
  `fitgenius-*` aliases, while retaining Aliyun as an environment-only rollback.
- Production form-analysis storage returned HTTP 200 with `mode: stored`.
- Production cloud-snapshot route deployed; unauthenticated and invalid-session
  requests return HTTP 401. Authenticated first-sync acceptance remains a
  physical-device step.
- Apple Watch simulator build, installation, and launch succeeded. The paired
  simulator received today's workout from iPhone and displayed its exercise,
  programmed sets/reps/weight, and set progress.
- Secret scan found no provider key or database URL in deployable files.
- Real-device Apple login and Apple Vision acceptance remain required.
- Simulator UI verified the AI Assistant annotated-feedback flow with the
  supplied bench video. The simulator used a DEBUG-only pose fixture because
  its Vision body-pose request was unavailable; real-joint overlay acceptance
  remains a physical-iPhone requirement.

Real video validation:

- Test video: `/Users/baojian/Downloads/IMG_8262.MOV`
- Duration: 15.77 seconds.
- Resolution: 2160 x 3840.
- Content: bench press.
- Pose extraction detected 16 usable frames.
- Joint counts per sampled frame: `[10, 9, 9, 10, 12, 12, 15, 15, 14, 11, 11, 14, 15, 15, 15, 15]`
- Bench result:
  - Score: 96
  - Pose quality: 97.9%
  - Detected frames: 16
  - Elbow flare metric: 0.149
  - Wrist asymmetry metric: 0.011
  - Wrist path metric: 0.086
  - Range of motion metric: 0.189
  - No major issues triggered.

UI issue fixed during smoke test:

- Onboarding step labels now render localized titles instead of raw keys such as `basic_info`.
- System-language behavior now also covers weekday formatting, AI reply
  language, speech recognition, fallback workout plans, Profile data, assistant
  controls, and Widget workout metadata.

## Immediate Next Steps

1. Complete physical-iPhone acceptance for Apple reconnect, Fitness/Diet image
   AI, and the unified PhotosPicker-to-real-Vision annotated-analysis flow.
2. Tune representative key-frame and overlay quality with real videos:
   - Camera-angle warnings.
   - More precise bottom-position control.
   - More robust bar/wrist path interpretation across camera angles.
3. Verify cloud snapshot restore with two Apple-authenticated devices.
4. Pair a physical Apple Watch and verify workout completion, heart rate, and
   HealthKit.
5. Complete the P0/P1 product-quality audit in `docs/product-quality-plan.md`.
6. Prepare a TestFlight release candidate.

## Important Assumptions

- Current priority is proving a small, useful iOS form-analysis loop.
- The product should not attempt all sports or all movements at once.
- The first valuable niche is gym strength-training users.
- Backend, Watch, and Android/Huawei support should be staged after iOS form-analysis value is proven.
- The app is currently free; subscription support is reserved but not launched.
- Any provider credential exposed outside the deployment environment must be
  rotated in that provider's dashboard.
