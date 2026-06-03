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

**Phase 2 status (partially complete, awaiting deploy + iOS wiring)**:
the backend code is complete (Apple Sign in endpoint, AI proxy, Neon
executor, schema migration script, 8 backend tests passing). The
iOS side has a complete client library (`AppleAuthAPIClient`,
`FormAnalysisSyncCoordinator`, `SyncSettings`, `AIService`) but the
call sites in `AuthViewModel` and `AIService` still need to be
wired before the app can use the backend in production. See
`docs/agent-handoff.md` for the list of Known Gaps.

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

## Current Implementation Status (verified against `main` @ 2026-06-03)

The bullet list below describes what is **actually in the repository on
the `main` branch right now**. Anything described as wired in earlier
drafts of this section was rolled back before the v1.1.0-stable
release and is no longer present in the working tree. The Known Gaps
in `docs/agent-handoff.md` list what has to be re-added before the
app store update is shippable.

Implemented and on `main`:

- iOS form analysis library: `Models/Form/*` (pose, form-analysis, sync
  payload, history), `Services/FormAnalysis/*` (rule engine, pose
  extraction, sync service, sync coordinator, sync settings, debug
  video provider), `ViewModels/FormAnalysisViewModel`,
  `Views/Plan/FormAnalysisView`, `Views/Components/VideoCameraPicker`,
  `Services/DebugSeedService`.
- iOS backend client library: `Services/AppleAuthAPIClient` (the HTTP
  client for `/api/auth/apple`), `Services/FormAnalysis/SyncSettings`
  (`UserDefaults` wrapper, no compile-time defaults), and the retry /
  backoff logic in `FormAnalysisSyncCoordinator`.
- Backend: `api/*` serverless functions, `backend/*` shared modules,
  `backend/tests/*` (8 `node --test` files), `package.json`,
  `vercel.json`, `.env.example`, `scripts/apply-schema.sh`,
  `scripts/predeploy-check.sh`, `scripts/run-form-analysis-tests.sh`,
  `scripts/check-localization.sh`.
- iOS 1.1.0 baseline: training plan, diet, stats, profile, Apple
  login (offline Keychain fallback), Widget, App Group data sharing,
  medical disclaimer UI, sources info, bilingual localization.
- Repo infrastructure: `.gitignore` (Claude Code project permissions
  excluded, Xcode artifacts excluded), `AGENTS.md` (multi-agent entry
  doc with architecture diagram), `PrivacyInfo.xcprivacy`.

Not yet on `main` (Known Gaps):

- `AuthViewModel.signIn(...)` does not call `AppleAuthAPIClient`.
- `AIService` does not call `/api/ai/chat`.
- `FormAnalysisView` is not reachable from `MainView`.
- `FormAnalysisSyncCoordinator` is not triggered by `scenePhase` or by
  `FormAnalysisViewModel.analyze(...)`.
- `Info.plist` is missing `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription`.
- Apple Watch (Phase 3) is not started.
- Android / cross-platform (Phase 4) is not started.

## Validation Log

Last verified on 2026-06-03, after the 6-commit cleanup:

- iOS build: `xcodebuild ... build` → `** BUILD SUCCEEDED **`
- iOS unit tests: `scripts/run-form-analysis-tests.sh` → 5 binaries
  pass (DebugVideoProvider, FormAnalysisSyncPayload, FormAnalysisSyncService,
  FormAnalysisSyncCoordinator, AppleAuthAPIClient)
- Backend tests: `npm run test:backend` → 8 files pass
  (appleTokenVerifier, sessionToken, appleAuthApi, aiChatProxy,
  formAnalysisRepository, formAnalysesApi, formAnalysisPayload, schema)
- Working tree clean; force-pushed to `origin/main`.
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
