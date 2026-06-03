# FitGenius Agent Handoff

Last updated: 2026-06-02 22:35 Asia/Shanghai

## Read First

Before making changes, read these files in order:

1. `AGENTS.md`
2. `docs/form-coach-roadmap.md`
3. `docs/agent-handoff.md`

This document exists so another agent can continue safely if the current conversation ends or usage limits are reached.

## User Priorities

- Build FitGenius into a personalized strength-training coach, not only a plan generator.
- Current MVP focus: iOS form analysis for gym strength users.
- Keep development incremental and validated.
- Preserve Chinese-first product quality while supporting English users through system language switching.
- Record progress in repo docs so future agents do not rely on chat history.

## Current Status

The local working tree contains Phase 1 form-analysis MVP work in progress and the first Phase 2 backend scaffold.

Implemented:

- Platform-neutral pose models:
  - `FitGenius/Models/Form/PoseModels.swift`
  - `FitGenius/Models/Form/FormAnalysisModels.swift`
  - `FitGenius/Models/Form/FormAnalysisHistory.swift`
- Backend-ready form-analysis sync payload:
  - `FitGenius/Models/Form/FormAnalysisSyncPayload.swift`
  - Uses stable exercise identifiers such as `squat`, `deadlift`, and `bench_press` instead of localized Chinese raw values.
  - `FormAnalysisRecord.syncPayload()` converts local SwiftData history into a Codable JSON payload.
  - `FormAnalysisRecord` now tracks sync status with `pending`, `synced`, and `failed`, plus last attempt/success dates and error message.
- Apple Vision pose extraction:
  - `FitGenius/Services/FormAnalysis/PoseExtractionService.swift`
- Local form rule engine:
  - `FitGenius/Services/FormAnalysis/FormRuleEngine.swift`
  - Supports squat, deadlift, bench press.
- Form-analysis view model:
  - `FitGenius/ViewModels/FormAnalysisViewModel.swift`
- Form-analysis sync service:
  - `FitGenius/Services/FormAnalysis/FormAnalysisSyncService.swift`
  - Builds authenticated JSON POST requests for `FormAnalysisSyncPayload`.
  - Encodes `Date` as ISO-8601 so it matches the backend validator.
  - Parses success and server-error responses.
- Form-analysis sync coordinator (Phase 2 wiring, no Vercel/Neon required):
  - `FitGenius/Services/FormAnalysis/SyncSettings.swift`
    - `UserDefaults`-backed config wrapper; no compile-time defaults.
    - `backendBaseURL` and `devSyncToken` keys are empty by default.
  - `FitGenius/Services/FormAnalysis/FormAnalysisSyncCoordinator.swift`
    - `@MainActor` singleton (`FormAnalysisSyncCoordinator.shared`).
    - `syncPendingRecords(context:userId:bearerToken:)` scans SwiftData
      for `pending` and `failed` records and POSTs them serially through
      `FormAnalysisSyncService`. Re-entrancy guarded by `isSyncing`.
    - `syncOneRecord(...)` writes back success / failure into the model
      and updates `@Published` state for SwiftUI binding.
    - `resolveEndpoint()` is exposed for tests and returns `nil` for
      missing / malformed config (silent no-op).
  - Triggers:
    - `FitGenius/FitGeniusApp.swift` listens to `scenePhase` and runs a
      full sync whenever the scene becomes `.active`.
    - `FitGenius/ViewModels/FormAnalysisViewModel.swift.analyze(...)` now
      accepts an optional `userId` and immediately syncs the freshly
      inserted record. `DEBUG` builds also pick up
      `FITGENIUS_SYNC_BACKEND_URL` and `FITGENIUS_DEV_SYNC_TOKEN` env
      vars to override `UserDefaults` at runtime.
  - `FitGenius/ViewModels/AuthViewModel.swift` exposes
    `currentBearerToken` sourced from `SyncSettings.live.devSyncToken` so
    the coordinator can stay decoupled from Keychain internals.
- Form-analysis UI:
  - `FitGenius/Views/Plan/FormAnalysisView.swift`
  - Supports photo-library video upload.
  - Supports camera recording on real devices with camera availability.
- Debug-only seed helper:
  - `FitGenius/Services/DebugSeedService.swift`
  - Enabled only in DEBUG and only when launched with `-FitGeniusSeedFormCoachDemo`.
  - Creates a demo user, demo plan, and squat/deadlift/bench exercises for simulator validation.
- Debug-only direct video helper:
  - `FitGenius/Services/FormAnalysis/DebugFormAnalysisVideoProvider.swift`
  - Enabled only in DEBUG.
  - Launch with `-FitGeniusDebugFormVideo /absolute/path/video.mov` to auto-load a local video when opening form analysis.
  - Supports `-FitGeniusDebugFormVideo=/absolute/path/video.mov` for script-friendly launches.
- Camera picker:
  - `FitGenius/Views/Components/VideoCameraPicker.swift`
- Workout integration:
  - `FitGenius/Views/Plan/WorkoutDayDetailView.swift`
  - Exercise row can open form analysis.
- Stats integration:
  - `FitGenius/ViewModels/StatsViewModel.swift`
  - `FitGenius/Views/Stats/StatsView.swift`
  - Shows recent form-analysis history and average score.
- SwiftData schema integration:
  - `FitGenius/FitGeniusApp.swift`
  - Includes `FormAnalysisRecord.self`.
- Localization:
  - Form-analysis UI, issues, metrics, recommendations, errors, exercise names, and stats card are localized in Simplified Chinese and English.
  - Workout exercise-row form-analysis action uses `form_analysis_action` instead of hardcoded Chinese text.
  - Check script: `scripts/check-localization.sh`.
- Roadmap:
  - `docs/form-coach-roadmap.md`.
- Phase 2 backend wiring (code-complete, awaiting Vercel + Neon deploy):
  - `backend/neonClient.mjs`
    - Real `@neondatabase/serverless` client. `createNeonExecutor(databaseUrl)` returns an `executeStatement({ text, values })` function that calls `sql.query(text, values)`.
  - `backend/database.mjs`
    - `createExecutor()` returns a Neon-backed `executeStatement` when `DATABASE_URL` is set, otherwise `null` (validated-only mode).
  - `backend/migrate.mjs` + `scripts/apply-schema.sh`
    - Idempotent migration script. Splits `schema.sql` on `;` (ignoring `--` comments) and applies each statement to Neon.
  - `package.json` `db:migrate` script.
  - `backend/appleTokenVerifier.mjs`
    - Verifies Apple-issued identity tokens with `jose.jwtVerify` against `https://appleid.apple.com/auth/keys`.
    - JWKS strategy: `createRemoteJWKSet(URL, { cacheMaxAge: 60*60*1000 })` (1h cache, jose handles dedup + rotation).
    - `__setAppleJWKSLoader` allows tests to inject a deterministic key set.
  - `backend/sessionToken.mjs`
    - HS256 session JWT (jose) signed with `SESSION_SECRET` (>= 32 chars).
    - Claims: `sub` (FitGenius userId), `apple_sub`, `iss=fitgenius`, `exp` (30d).
    - `extractBearerToken()` parses `Authorization: Bearer xxx` headers.
  - `api/auth/apple.js`
    - `POST /api/auth/apple` accepts `{ identityToken, userIdentifier, fullName? }`.
    - Verifies the token, upserts into `users`, signs and returns a session JWT.
    - Falls back to `validated_only` when no DB executor is configured.
  - `api/ai/chat.js`
    - `POST /api/ai/chat` accepts `{ messages, model?, stream? }`.
    - Verifies the bearer token (session JWT), then proxies the request to Aliyun using the server-side `ALIYUN_API_KEY`.
    - Forwards both streaming (SSE) and non-streaming responses.
  - `backend/tests/appleTokenVerifier.test.mjs`
  - `backend/tests/sessionToken.test.mjs`
  - `backend/tests/appleAuthApi.test.mjs`
  - `backend/tests/aiChatProxy.test.mjs`
  - `vercel.json` declares `api/auth/*.js` and `api/ai/*.js` function runtimes plus placeholder env references.
  - `.env.example` documents `DATABASE_URL`, `SESSION_SECRET`, `APPLE_BUNDLE_ID`, `ALIYUN_API_KEY`, `SESSION_ISSUER`, `BACKEND_PUBLIC_URL`, `FITGENIUS_DEV_SYNC_TOKEN`.
- iOS Phase 2 wiring (code-complete, awaiting Vercel deploy):
  - `FitGenius/Services/AuthService.swift` returns `AppleSignInResult` with the raw `identityToken` and `PersonNameComponents` so the backend can do Apple ID verification.
  - `FitGenius/Services/AppleAuthAPIClient.swift` POSTs to `/api/auth/apple` and decodes the session payload.
  - `FitGenius/Services/FormAnalysis/SyncSettings.swift`
    - Adds `sessionToken`, `sessionUserId`, and `bearerToken` (prefers real session, falls back to dev token).
    - `appleAuthBaseURL` helper for the auth + AI clients.
  - `FitGenius/ViewModels/AuthViewModel.swift`
    - `signIn(context:)` exchanges the Apple identityToken for a session JWT and stores it through `SyncSettings`.
    - Falls back to the local Keychain-stored Apple user id when the backend is not configured (so DEBUG / simulator builds keep working).
    - `currentBearerToken` now sources from the real session token, with dev token as fallback.
  - `FitGenius/Services/AIService.swift`
    - `baseURL` is now `{SyncSettings.backendBaseURL}/api/ai/chat`.
    - Sends `Authorization: Bearer <sessionToken>` to the proxy.
    - The local Aliyun key path is kept as an offline fallback (used only when no `backendBaseURL` is set).
  - `FitGenius/Services/FormAnalysis/FormAnalysisSyncCoordinator.swift`
    - `syncOneRecord` now retries up to 3 times with exponential backoff (2s, 4s, 8s).
    - `sleepProvider` indirection so tests can advance time without real waits.

Security cleanup already performed:

- Removed hardcoded Aliyun API key from `FitGenius/Info.plist`.
- Removed exposed key/build setting from `FitGenius.xcodeproj/project.pbxproj`.
- Removed shared scheme API key environment variable from `FitGenius.xcodeproj/xcshareddata/xcschemes/FitGenius.xcscheme`.
- Secret scan found no remaining `sk-...` or committed `ALIYUN_API_KEY` setting.

Important: if a real Aliyun key was previously exposed, the user still needs to rotate it in the provider dashboard.

## Dirty Working Tree Warning

Current branch state observed during this work:

- `main...origin/main [ahead 14]`
- The working tree has many modified and untracked files.
- Some modified files predate the form-analysis work and appear related to App Store compliance, profile data export/import, account deletion, and source/disclaimer updates.

Do not reset, checkout, or revert files unless the user explicitly asks.

Known pre-existing or parallel changes include:

- `FitGenius/Services/AIService.swift`
- `FitGenius/ViewModels/AuthViewModel.swift`
- `FitGenius/Views/Assistant/AIAssistantView.swift`
- `FitGenius/Views/Profile/ProfileView.swift`
- `FitGenius/Views/Profile/SourcesInfoView.swift`
- `FitGenius/Views/Stats/StatsView.swift`
- `FitGenius/en.lproj/Localizable.strings`
- `FitGenius/zh-Hans.lproj/Localizable.strings`
- `FitGenius/PrivacyInfo.xcprivacy`

## Latest Validation

Passed:

- `BenchRangeTests passed`
- `DebugVideoProviderTests passed`
- `FormAnalysisSyncPayloadTests passed`
- `FormAnalysisSyncServiceTests passed`
- `FormAnalysisSyncCoordinatorTests passed` (6 cases: happy path, failure path, empty store, skipped `.synced`, no backend URL, no bearer token)
- `formAnalysesApi tests passed`
- `appleTokenVerifier tests passed`
- `sessionToken tests passed`
- `appleAuthApi tests passed`
- `aiChatProxy tests passed`
- `npm run test:backend` passed (7/7).
- iOS Simulator build with the Phase 2 wiring: `xcodebuild ... build` returned `** BUILD SUCCEEDED **`.
- Secret scan: `rg "sk-[A-Za-z0-9]|ALIYUN_API_KEY =[^[:space:]]|<key>ALIYUN" -n .` returned no matches.
- `scripts/run-form-analysis-tests.sh` passed (4 binaries).
- `scripts/check-localization.sh` passed with 70 required keys.
- `FormRuleEngineTests passed`
- `BenchRuleTests passed`
- `PoseQualityTests passed`
- `FormHistoryTests passed`
- iOS Simulator build:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitGenius.xcodeproj -scheme FitGenius -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FitGeniusDerivedData CODE_SIGNING_ALLOWED=NO build`
- XcodeBuildMCP simulator build passed. Current compiler warnings remain in existing files:
  - `FitGenius/Services/AIService.swift`: unused `apiKey`, `url`, and `systemMessage`.
  - `FitGenius/ViewModels/AuthViewModel.swift`: non-exhaustive switch warning.
- Latest XcodeBuildMCP simulator build passed with no warnings in the returned diagnostics.
- Simulator install and launch for bundle id:
  `com.swordingk.fitgenius`
- Simulator DEBUG seed launch with:
  `-FitGeniusSeedFormCoachDemo`
- Simulator DEBUG direct video launch with:
  `-FitGeniusDebugFormVideo /Users/baojian/Downloads/IMG_8262.MOV`
- UI automation verified:
  - App opens directly to the seeded training plan.
  - Bench press row exists.
  - Bench press row analysis action opens the form-analysis sheet.
  - Exercise type is inferred as bench press.
  - PhotosPicker opens and shows the imported bench press video.
  - DEBUG direct video path auto-loads the user video into the form-analysis sheet.
  - Simulator Vision request currently returns unavailable for `VNDetectHumanBodyPoseRequest`; the UI now shows a localized Chinese error instead of the raw English Vision error.
- Smoke screenshots:
  - `/tmp/fitgenius-formcoach-smoke.png`
  - `/tmp/fitgenius-formcoach-smoke-fixed.png`
  - `/tmp/fitgenius-seeded-main.png`
  - `/tmp/fitgenius-after-photo-click2.png`
  - `/var/folders/t4/p0g6jxt90533vv_3h82mtrnw0000gn/T/screenshot_optimized_a1f14810-f9cd-4505-b178-5dec2e72277f.jpg`
- Secret scan:
  `rg "sk-[A-Za-z0-9]|ALIYUN_API_KEY =|<key>ALIYUN_API_KEY" -n . -g '!*.xcuserstate' -g '!*.png'`
  returned no matches.

Real video validation:

- User test video: `/Users/baojian/Downloads/IMG_8262.MOV`
- Content: bench press.
- Duration: 15.77 seconds.
- Resolution: 2160 x 3840.
- Pose extraction: 16 usable frames.
- Bench result:
  - Score: 96
  - Pose quality: 97.9%
  - Detected frames: 16
  - Elbow flare metric: 0.149
  - Wrist asymmetry metric: 0.011
  - Wrist path metric: 0.086
  - Range of motion metric: 0.189
  - No major issues triggered.

Note: standalone Swift command-line scripts may print localization keys because they do not run inside the app bundle. The iOS build packages `Localizable.strings`.

## Product And Technical Principles

- Chinese is the primary quality baseline; English must remain available through system language switching.
- New user-facing text must be added to both `zh-Hans` and `en`.
- Do not hardcode visible UI text unless it is user-generated content or intentionally not localizable.
- Rules must remain independent of Apple Vision types.
- Apple Vision only extracts pose; coaching decisions come from FitGenius rules.
- Do not provide medical diagnosis. Keep output as training guidance.
- iPhone handles video analysis. Apple Watch, when added, should start with workout assistance rather than video recognition.
- Android/Huawei support should reuse platform-neutral pose data, not Apple-specific types.

## Next Recommended Work

1. Continue full in-app UI flow from PhotosPicker:
   - Current status: video is imported and visible in the picker.
   - Current blocker: the system PhotosPicker grid does not expose an elementRef to XcodeBuildMCP, and coordinate clicking has not selected the thumbnail yet.
   - A DEBUG-only direct video-file analysis path now exists, so future validation can bypass PhotosPicker for simulator UI flow checks.
   - Current remaining blocker: Vision body-pose request is unavailable in the current simulator runtime. Validate actual pose extraction on a real iPhone before treating this as production-ready.
2. Continue bench-specific coaching quality:
   - Range-of-motion metric and limited-range issue are now implemented.
   - Remaining candidates: camera-angle warnings and more precise bottom-position control.
3. Continue Phase 2 backend from the new scaffold:
   - `FormAnalysisSyncPayload` is ready as the first contract for form-analysis history sync.
   - `FormAnalysisSyncService` is ready to POST local records once a backend URL and user id/token source are added.
   - `FormAnalysisRecord` has local sync state, so future work can query pending/failed records for retry.
   - `FormAnalysisSyncCoordinator` is wired and triggered from `scenePhase == .active` and from each successful `FormAnalysisViewModel.analyze(...)`. It silently no-ops when no `backendBaseURL` is configured.
   - `backend/schema.sql` defines `users` and `form_analysis_records`.
   - API handler stored-mode is unit-tested through injected `executeStatement`.
   - Next backend step: create Vercel + Neon, apply schema, add a real Neon client in `backend/database.mjs`, and pass it into `createFormAnalysesHandler`.
   - Then wire real Apple ID token exchange so `AuthViewModel.currentBearerToken` no longer relies on the dev `SyncSettings` token.
   - Do not store real `DATABASE_URL`, `FITGENIUS_DEV_SYNC_TOKEN`, or `ALIYUN_API_KEY` in the repository.
   - Phase 2 code work is now complete on this branch. The remaining steps are environmental: provision a Vercel project + Neon database, set the env vars, run `./scripts/apply-schema.sh`, and verify the iOS app reaches `/api/auth/apple` and `/api/ai/chat`.
4. Continue localization cleanup when touching old pages:
   - Stats chart axis labels still contain older hardcoded Chinese.
   - Some legacy pages may still rely on raw localization keys or hardcoded text.
5. Prepare a clean branch/commit strategy before pushing:
   - Separate form-analysis MVP changes from older App Store compliance changes if possible.
   - Do not commit secrets.

## Useful Commands

Build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitGenius.xcodeproj -scheme FitGenius -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FitGeniusDerivedData CODE_SIGNING_ALLOWED=NO build
```

Localization check:

```bash
scripts/check-localization.sh
```

Secret scan:

```bash
rg "sk-[A-Za-z0-9]|ALIYUN_API_KEY =|<key>ALIYUN_API_KEY" -n . -g '!*.xcuserstate' -g '!*.png'
```

Current simulator previously used:

```text
iPhone 17 Pro
E56B68EF-83D1-4D0C-8566-891285CCB0CC
```

Launch with demo seed:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch --terminate-running-process E56B68EF-83D1-4D0C-8566-891285CCB0CC com.swordingk.fitgenius -FitGeniusSeedFormCoachDemo
```

Launch with demo seed and direct DEBUG video:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch --terminate-running-process E56B68EF-83D1-4D0C-8566-891285CCB0CC com.swordingk.fitgenius -FitGeniusSeedFormCoachDemo -FitGeniusDebugFormVideo /Users/baojian/Downloads/IMG_8262.MOV
```
