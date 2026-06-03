# FitGenius Agent Handoff

Last updated: 2026-06-03 18:25 Asia/Shanghai

## Read First

Before making changes, read these files in order:

1. `AGENTS.md` — project structure, tech stack, key invariants
2. `docs/form-coach-roadmap.md` — long-term product plan
3. `docs/agent-handoff.md` — current state and known gaps (this file)

This document exists so another agent can continue safely if the current conversation ends or usage limits are reached.

## User Priorities

- Build FitGenius into a personalized strength-training coach, not only a plan generator.
- Current MVP focus: iOS form analysis for gym strength users.
- Keep development incremental and validated.
- Preserve Chinese-first product quality while supporting English users through system language switching.
- Record progress in repo docs so future agents do not rely on chat history.

## Current Status (verified 2026-06-03)

The repository is committed in 7 clean milestone commits on top of the v1.1.0-stable baseline. All planned commits landed:

| SHA | Subject | Status |
|---|---|---|
| `c6c3561` | chore(repo): upgrade gitignore and rewrite AGENTS.md | done |
| `189e487` | fix(security): remove committed Aliyun API key | done |
| `fe20405` | feat(compliance): add PrivacyInfo.xcprivacy manifest | done |
| `14f587d` | feat(form-analysis): iOS MVP for squat / deadlift / bench | done |
| `d84aa21` | feat(backend): Vercel + Neon + Apple auth + AI proxy | done |
| `2288c39` | feat(ios): add AppleAuthAPIClient | done |
| `60c6eaf` | feat(ios): wire Apple token exchange + AI proxy + sync trigger | done |

Validation (re-run 2026-06-03 18:25):

- `xcodebuild ... build` → `** BUILD SUCCEEDED **`
- `scripts/run-form-analysis-tests.sh` → 5/5 pass (`AppleAuthAPIClientTests` + 4 form analysis suites)
- `npm run test:backend` → 8/8 pass
- Working tree clean
- `git push origin main` via HTTPS → `1ef73fa..60c6eaf`

## What Actually Works Without Further Work

These are real on a v1.1.0 build with the new commits applied:

- iOS training, diet, stats, profile, Apple login (offline Keychain fallback)
- iOS Widget (App Group)
- Local form analysis rule engine (`FormRuleEngine` + `PoseExtractionService` against a recorded video)
- Local SwiftData persistence of form analysis records
- Backend HTTP endpoints: `/api/health`, `/api/auth/apple`, `/api/ai/chat`, `/api/form-analyses` (code-complete)
- iOS `AppleAuthAPIClient` can POST to `/api/auth/apple` if a caller invokes it

## Known Gaps (must be finished before app store submission)

1. **`FormAnalysisView` is unreachable from `MainView`.**
   The view file is committed but no Tab / NavigationLink opens it. Users cannot access the form-analysis feature from the UI. *Tracked for Phase 3 — requires a "pick an exercise" picker UI since `FormAnalysisView` currently requires `@Bindable var exercise: Exercise`.*
2. **No `FormAnalysisViewModel.analyze(...)` trigger of `FormAnalysisSyncCoordinator`.**
   `FitGeniusApp` scenePhase listener now triggers the sync, but the in-flight `analyze(...)` path does not — the user-visible latency for a successful sync will only happen on next foreground transition. (Acceptable for the first release.)
3. **Vercel + Neon not yet deployed.**
   The user has Vercel/Neon accounts and a Vercel project (`fitgenius`) from Codex. Need to: set env vars in Vercel, apply schema to Neon, set `backendBaseURL` in iOS via UserDefaults, configure Apple Developer bundle id capability.
4. **No Aliyun API key rotation story yet.**
   Key is read from Vercel env. If compromised, rotate in Vercel and redeploy — iOS does not need to be rebuilt.

## iOS Phase 2 Wiring — DONE (`60c6eaf`)

- `AuthService.signInWithApple()` → returns `AppleSignInResult` (with `identityToken: Data?`).
- `AuthViewModel.signIn(context:)` → calls `apiClient.exchange(identityToken:userIdentifier:fullName:)` and stores session via `settings.setSessionToken(...)`.
- `AuthViewModel.currentBearerToken` → `settings.bearerToken` (session token, falls back to dev token).
- `AIService` → `resolveRequestURL()` / `resolveAuthHeader()` prefer `backendBaseURL/api/ai/chat` with `Authorization: Bearer`; direct Aliyun kept as offline fallback.
- `FitGeniusApp` → `@Environment(\.scenePhase)` + `.onChange(of: scenePhase)` triggers `FormAnalysisSyncCoordinator.shared.syncPendingRecords(...)` when scene becomes `.active`.
- `FormAnalysisSyncCoordinator` → 3 attempts × exponential backoff (2s/4s/8s) via `sleepProvider` injection.

## Deployment Runbook (Vercel + Neon)

Total time: 15–20 min. No code changes required; everything is in the repo.

### 1. Create a Neon Postgres database (5 min)

1. Open https://console.neon.tech and sign up (GitHub SSO recommended).
2. Click **Create a project**. Pick a region close to your users.
3. Copy the **Connection string** from the dashboard. It looks like `postgres://user:pwd@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require`.
4. Apply the schema locally:
   ```bash
   cd /Users/baojian/Desktop/Xcode项目/FitGenius
   DATABASE_URL='postgres://...' bash scripts/apply-schema.sh
   ```
   You should see two `CREATE TABLE` log lines for `users` and `form_analysis_records`.

### 2. Create a Vercel project (10 min)

1. Open https://vercel.com and sign up (GitHub SSO recommended).
2. Click **Add New → Project → Import `swording-k/fit-genius`**.
3. **Do not deploy yet** — first set the environment variables. Open the project **Settings → Environment Variables** and add the following for the **Production** environment:

   | Key | Value | Notes |
   |---|---|---|
   | `DATABASE_URL` | paste the Neon string from step 1 | required |
   | `ALIYUN_API_KEY` | your Aliyun OpenAI-compatible key | required for `/api/ai/chat` |
   | `SESSION_SECRET` | `openssl rand -hex 32` output | required, ≥32 chars |
   | `APPLE_BUNDLE_ID` | `com.swordingk.fitgenius` | must match the iOS bundle id |
   | `SESSION_ISSUER` | `fitgenius` | optional, default `fitgenius` |
   | `BACKEND_PUBLIC_URL` | leave empty on first deploy; fill in once the Vercel URL is known | optional |

4. Click **Deploy**. Vercel builds the `api/*.js` serverless functions.
5. When deploy finishes, copy the project URL (e.g. `https://fit-genius-xxx.vercel.app`).

### 3. Smoke-test the backend (1 min)

```bash
# Health check (no auth)
curl https://fit-genius-xxx.vercel.app/api/health
# Expected: {"ok":true,...}

# Form analysis endpoint should 401 without auth
curl -i -X POST https://fit-genius-xxx.vercel.app/api/form-analyses -H 'Content-Type: application/json' -d '{}'
# Expected: 401 with a JSON error body
```

### 4. Point the iOS app at the backend

The iOS app reads the backend URL from `UserDefaults` under the key
`fitgenius.sync.backendBaseURL`. In Xcode, set it in the scheme's
**Run → Arguments → Environment Variables** for debug builds:

```
fitgenius.sync.backendBaseURL = https://fit-genius-xxx.vercel.app
```

Or for a more permanent setting, drop the value into a `Config.plist`
(not committed) and read it in `SyncSettings`.

### 5. Re-deploy after wiring the iOS code

Once items 1–4 of **Known Gaps** are closed, the backend needs no
changes. Just rebuild and re-archive the iOS app.

## Build & Release (iOS)

The user already has the Apple Developer account. Three steps from a clean tree:

```bash
# 1. Make sure the tree is what you expect
git status --short
# (empty)

# 2. Build the simulator target to catch any compile error
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project FitGenius.xcodeproj -scheme FitGenius \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/FitGeniusDerivedData \
  CODE_SIGNING_ALLOWED=NO build
# Expect: ** BUILD SUCCEEDED **

# 3. Archive for distribution (uses your signing identity)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project FitGenius.xcodeproj -scheme FitGenius \
  -archivePath /tmp/FitGenius.xcarchive \
  -destination 'generic/platform=iOS' \
  archive
```

Then in Xcode → **Organizer → Distribute App → App Store Connect → Upload**.
Or, if you prefer the command line:

```bash
xcodebuild -exportArchive \
  -archivePath /tmp/FitGenius.xcarchive \
  -exportPath /tmp/FitGenius-export \
  -exportOptionsPlist exportOptions.plist

# Upload with altool
xcrun altool --upload-app \
  -f /tmp/FitGenius-export/FitGenius.ipa \
  -t ios \
  -u "$APPLE_ID_EMAIL"
```

## Next Recommended Work

In priority order (smallest first):

1. Add `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` to `Info.plist` (5 min)
2. Add a "Form Analysis" entry button in `MainView` (10 min)
3. Wire `AuthViewModel.signIn(...)` to call `AppleAuthAPIClient.exchange(...)` (30 min)
4. Wire `AIService` to POST `/api/chat` (30 min)
5. Wire `FormAnalysisSyncCoordinator` from `FitGeniusApp` `scenePhase == .active` (15 min)
6. After (1–5), run `scripts/predeploy-check.sh` and then deploy.

## Out of Scope (Phase 3+)

- Apple Watch experience (today's workout, set/rest timer, HR display, HealthKit write)
- Android / Huawei expansion
- Subscription / billing
- Per-user analytics dashboard
