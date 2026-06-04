# FitGenius Agent Handoff

Last updated: 2026-06-04 11:35 Asia/Shanghai

## Read First

1. `AGENTS.md`
2. `docs/form-coach-roadmap.md`
3. `docs/product-quality-plan.md`
4. `docs/agent-handoff.md`

## Current Status

The current product-stabilization milestone is deployed to the existing Vercel
production project and committed on `main`.

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

Important: the production `SESSION_SECRET` changed during repair. Existing
phone sessions are invalid. Users with the old local Apple identity must use the
new reconnect prompt once to receive a new FitGenius cloud session.

## Latest Validation

- XcodeBuildMCP simulator build and run: succeeded with zero diagnostics.
- Simulator UI:
  - form-analysis button appears for the three supported demo exercises;
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

1. Open **My**.
2. Tap the Apple reconnect prompt or log in with Apple.
3. Open AI Assistant and send a short message.
4. Open a squat/deadlift/bench exercise, tap the green form-analysis icon, and
   analyze a 10-30 second video.

This is required because Apple authorization UI and real-device Vision behavior
cannot be fully accepted in Simulator.

## Next Recommended Work

1. Complete a full bilingual UX audit of Training, Diet, AI, Stats, and Profile.
2. Add conversation/session organization so AI history is manageable long term.
3. Add form-analysis history and progress summaries to Stats.
4. Run physical-device acceptance and create a TestFlight release candidate.
5. Start the Apple Watch companion only after the iPhone quality gates pass.

## Risks

- Do not reset or overwrite work that is not understood.
- Do not rotate or print production secrets. They exist only in Vercel.
- Do not reintroduce an AI provider key into the iOS app or GitHub.
- Do not treat a successful build as proof of Apple login or Vision on a
  physical device.
