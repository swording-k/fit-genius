# FitGenius Form Coach Roadmap

Last updated: 2026-06-04

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
Neon. Existing phone sessions must reconnect once because the production
session secret was repaired.

### Phase 3: Apple Watch Experience

The first watchOS experience should support training-session assistance, not video analysis:

- Today's workout.
- Current exercise.
- Set/rest timer.
- Mark set or exercise complete.
- Heart-rate display.
- HealthKit workout writing.

Video analysis stays on iPhone.

### Phase 4: Android and Huawei Expansion

Only start after the iOS form-analysis MVP proves user value.

Cross-platform strategy:

- Reuse the backend, training models, and pose schema.
- Use MediaPipe or platform pose APIs to generate `PoseFrame`.
- Keep exercise rules and coaching logic aligned across clients.

## Current Implementation Status (verified 2026-06-04)

Implemented:

- Reachable iOS form-analysis flow for squat, deadlift, and bench press.
- Platform-neutral pose models, Apple Vision extraction, local rule engine,
  local history persistence, recommendation application, and cloud sync.
- Apple login exchange, FitGenius sessions, Vercel AI proxy, and Neon storage.
- Offline training/diet baseline, Widget, compliance screens, and bilingual
  localization.
- Product stabilization for AI connection state, newest-message chat opening,
  Profile debug-control removal, and Stats filtering/empty states.

Not started:

- Apple Watch companion.
- Android/Huawei clients.
- Subscription and billing.

## Validation Log

Last verified on 2026-06-04:

- Generic iOS Simulator build and XcodeBuildMCP build/run succeeded.
- Simulator UI verified the form-analysis entry, newest-message AI chat,
  debug-free Profile, and localized Stats empty state.
- `scripts/run-form-analysis-tests.sh`: 5/5 binaries passed.
- `npm run test:backend`: 15/15 tests passed.
- `scripts/check-localization.sh`: 70/70 required form-coach keys passed.
- Production AI non-streaming and streaming requests returned real Qwen output.
- Production form-analysis storage returned HTTP 200 with `mode: stored`.
- Secret scan found no provider key or database URL in deployable files.
- Real-device Apple login and Apple Vision acceptance remain required.

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

## Immediate Next Steps

1. Complete physical-iPhone acceptance for Apple reconnect, AI chat, and the
   PhotosPicker-to-analysis flow. Real-device validation remains required for
   Apple Vision.
2. Complete the P0/P1 product-quality audit in `docs/product-quality-plan.md`.
3. Tune remaining bench-specific report quality:
   - Camera-angle warnings.
   - More precise bottom-position control.
   - More robust bar/wrist path interpretation across camera angles.
4. Add form-analysis history and trends to Stats.
5. Prepare a TestFlight release candidate before starting Apple Watch work.

## Important Assumptions

- Current priority is proving a small, useful iOS form-analysis loop.
- The product should not attempt all sports or all movements at once.
- The first valuable niche is gym strength-training users.
- Backend, Watch, and Android/Huawei support should be staged after iOS form-analysis value is proven.
- The app is currently free; subscription support is reserved but not launched.
- Any exposed Aliyun key must be rotated in the provider dashboard.
