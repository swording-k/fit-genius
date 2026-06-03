# FitGenius Form Coach Roadmap

Last updated: 2026-06-02

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

**Phase 2 status (code-complete, awaiting deploy)**: the Apple Sign in
endpoint, AI proxy, Neon executor, schema migration script, and the
iOS client wiring (auth + AI service + retry/backoff) are all
implemented and tested locally. Provisioning the Vercel project + Neon
database and applying the schema are the only remaining steps before
the backend is live.

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

## Current Implementation Status

Implemented in the local working tree:

- Added platform-neutral pose and form-analysis models.
- Added backend-ready `FormAnalysisSyncPayload` with stable exercise identifiers for future sync.
- Added local sync state to `FormAnalysisRecord` for pending/synced/failed form-analysis history retries.
- Added `FormAnalysisSyncService` so iOS can POST form-analysis payloads to the backend once an endpoint/token is configured.
- Added `FormAnalysisSyncCoordinator` + `SyncSettings` so pending / failed `FormAnalysisRecord` rows are automatically synced from the iOS app.
  - `SyncSettings` is a `UserDefaults` wrapper with no compile-time defaults; the coordinator silently no-ops when `fitgenius.sync.backendBaseURL` is empty.
  - Triggered from `scenePhase == .active` and from each successful `FormAnalysisViewModel.analyze(...)`.
  - Predicate selects `pending` and `failed` records (re-tries failed records indefinitely; no attempt counter yet).
  - `AuthViewModel.currentBearerToken` surfaces the dev token from `SyncSettings` so the coordinator stays decoupled from Keychain internals.
- Added `FormRuleEngine` for squat, deadlift, and bench press.
- Added `PoseExtractionService` using Apple Vision.
- Added `FormAnalysisRecord` SwiftData model.
- Added `FormAnalysisViewModel`.
- Added `FormAnalysisView`.
- Added video recording entry for devices with a camera, while keeping photo-library upload.
- Added form-analysis entry from workout exercise rows.
- Added form-analysis history summary.
- Added form-quality section to training stats.
- Tuned pose quality to use exercise-specific required joints so bench press is not penalized for missing lower-body keypoints.
- Lowered the per-frame extraction threshold to 6 body keypoints so upper-body bench videos are accepted more reliably.
- Added bench press range-of-motion metric and limited-range issue detection.
- Added bench press camera-angle metric and camera-angle warning.
- Added a DEBUG-only demo seed launch path for simulator validation with `-FitGeniusSeedFormCoachDemo`.
- Added a DEBUG-only direct video launch path with `-FitGeniusDebugFormVideo` so simulator UI validation can bypass PhotosPicker automation limits.
- Added localized unavailable-state handling for Vision pose detection failures.
- Fixed onboarding progress labels so localized step names render instead of raw localization keys.
- Localized the workout-row form-analysis action label instead of hardcoding Chinese text.
- Localized the form-analysis UI, form-analysis stats card, exercise names, rule-engine issue text, metric labels, recommendations, and extraction errors.
- Added `scripts/check-localization.sh` to verify required form-analysis keys exist in both Simplified Chinese and English resources.
- Added `docs/agent-handoff.md` and updated `AGENTS.md` with required handoff rules for future agents.
- Removed hardcoded Aliyun API key from Info.plist, Xcode build settings, and shared scheme.
- Fixed diet JSON prompt conflict so JSON analysis does not require text outside JSON.
- Phase 2 backend wiring (code-complete, awaiting deploy):
  - Added a real `@neondatabase/serverless` executor in `backend/neonClient.mjs` and re-wired `backend/database.mjs` so `createFormAnalysesHandler` consumes it through the existing dependency-injection seam.
  - Added an idempotent migration script (`backend/migrate.mjs` + `scripts/apply-schema.sh`) and a `db:migrate` npm script.
  - Added Apple ID token verification (`backend/appleTokenVerifier.mjs`, jose `createRemoteJWKSet` with 1h cache), HS256 session JWT helpers (`backend/sessionToken.mjs`), `POST /api/auth/apple` (`api/auth/apple.js`), and `POST /api/ai/chat` (`api/ai/chat.js`).
  - Added four backend test files: `appleTokenVerifier.test.mjs`, `sessionToken.test.mjs`, `appleAuthApi.test.mjs`, `aiChatProxy.test.mjs`.
  - `vercel.json` declares the new function runtimes; `.env.example` documents the full env list (`DATABASE_URL`, `SESSION_SECRET`, `APPLE_BUNDLE_ID`, `ALIYUN_API_KEY`, `SESSION_ISSUER`, `BACKEND_PUBLIC_URL`, `FITGENIUS_DEV_SYNC_TOKEN`).
  - `backend/README.md` documents endpoints, required env, local validation, schema setup, the iOS integration flow, and security notes.
- Phase 2 iOS wiring (code-complete, awaiting deploy):
  - `AuthService.signInWithApple()` now returns `AppleSignInResult` with the raw identityToken.
  - `AppleAuthAPIClient` POSTs to `/api/auth/apple` and decodes the session payload.
  - `SyncSettings` now stores `sessionToken` / `sessionUserId` and exposes `bearerToken` (prefers real session, falls back to dev token).
  - `AuthViewModel` exchanges the identityToken for a session token on sign in and persists it.
  - `AIService` now talks to `{backendBaseURL}/api/ai/chat` by default and sends `Authorization: Bearer <sessionToken>`. The local Aliyun key path is kept only as an offline fallback for builds without a backend URL.
  - `FormAnalysisSyncCoordinator.syncOneRecord` retries 3 times with exponential backoff (2s, 4s, 8s). A `sleepProvider` indirection lets tests advance time without real waits.
- Started Phase 2 backend scaffold (preceding bullet set still in place):

## Validation Log

Automated checks completed:

- `FormRuleEngineTests passed`
- `BenchRuleTests passed`
- `BenchRangeTests passed`
- `BenchCameraAngleTests passed`
- `DebugVideoProviderTests passed`
- `FormAnalysisSyncPayloadTests passed`
- `FormAnalysisSyncServiceTests passed`
- `FormAnalysisSyncCoordinatorTests passed` (6 cases).
- `formAnalysesApi tests passed`
- `npm run test:backend` passed.
- `scripts/run-form-analysis-tests.sh` passed.
- `PoseQualityTests passed`
- `FormHistoryTests passed`
- `scripts/check-localization.sh` passed with 70 required form-analysis keys.
- Xcode simulator build succeeded with:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitGenius.xcodeproj -scheme FitGenius -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FitGeniusDerivedData CODE_SIGNING_ALLOWED=NO build`
- Simulator install and launch succeeded for `com.swordingk.fitgenius`.
- DEBUG seed launch succeeded and opened the demo training plan.
- UI automation verified the seeded bench press row can open the form-analysis sheet with bench press inferred.
- PhotosPicker opened and displayed the imported bench press video; automated thumbnail selection remains a tooling limitation because the system picker grid did not expose a usable element reference.
- DEBUG direct video launch auto-loaded `/Users/baojian/Downloads/IMG_8262.MOV` into the form-analysis sheet.
- In the current simulator runtime, `VNDetectHumanBodyPoseRequest` cannot be set up inside the app. The UI now shows a localized Chinese unavailable-state message instead of the raw English Vision error. Real-device validation is still required for the Apple Vision extraction path.
- Screenshot confirmed app launches to onboarding.
- Secret scan found no remaining `sk-...` or committed `ALIYUN_API_KEY` build setting.
- Smoke screenshot after latest build: `/tmp/fitgenius-formcoach-smoke.png`
- Smoke screenshot after onboarding label fix: `/tmp/fitgenius-formcoach-smoke-fixed.png`

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

1. Finish the PhotosPicker-to-analysis UI flow:
   - Current verified point: workout row -> form analysis sheet -> PhotosPicker with imported video visible.
   - Remaining issue: automated thumbnail selection is blocked by system picker tooling; use the DEBUG direct video launch path for automated simulator checks or manually select in Simulator.
   - Real-device validation is required because the current simulator cannot set up `VNDetectHumanBodyPoseRequest` inside the app.
2. Tune remaining bench-specific report quality:
   - Camera-angle warnings.
   - More precise bottom-position control.
   - More robust bar/wrist path interpretation across camera angles.
3. Create a clean development branch and commit the MVP.
4. Review and preserve existing App Store compliance changes.
5. Continue Phase 2 backend:
   - Create Vercel and Neon project.
   - Apply `backend/schema.sql` (run `./scripts/apply-schema.sh` or `npm run db:migrate`).
   - Wire Apple Developer "Sign in with Apple" capability for the iOS bundle id and confirm `APPLE_BUNDLE_ID` matches.
   - Populate Vercel project env: `DATABASE_URL`, `SESSION_SECRET` (32+ chars), `APPLE_BUNDLE_ID`, `ALIYUN_API_KEY`, optional `SESSION_ISSUER`, `BACKEND_PUBLIC_URL`, `FITGENIUS_DEV_SYNC_TOKEN`.
   - Verify the iOS app reaches `/api/auth/apple` and `/api/ai/chat` end to end. The retry-with-backoff path is in place for transient network failures.
   - Keep all provider keys in Vercel environment variables only.

## Important Assumptions

- Current priority is proving a small, useful iOS form-analysis loop.
- The product should not attempt all sports or all movements at once.
- The first valuable niche is gym strength-training users.
- Backend, Watch, and Android/Huawei support should be staged after iOS form-analysis value is proven.
- The app is currently free; subscription support is reserved but not launched.
- Any exposed Aliyun key must be rotated in the provider dashboard.
