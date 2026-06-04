# FitGenius Agent Handoff

Last updated: 2026-06-04 15:40 Asia/Shanghai

## Read First

1. `AGENTS.md`
2. `docs/form-coach-roadmap.md`
3. `docs/product-quality-plan.md`
4. `docs/agent-handoff.md`

## Current Status

The backend stabilization milestone remains deployed. The new user-visible iOS
milestone is committed on `main` and awaiting physical-iPhone acceptance before
release.

Completed in the current local milestone:

- Fitness and Diet AI images are normalized to bounded JPEG data before upload;
  attached images can be sent without typed text.
- Diet AI now distinguishes an expired cloud session and presents the Apple
  reconnect action instead of a generic failure.
- Video exercise selection defaults to local automatic detection among squat,
  deadlift, and bench press, while retaining a manual override.
- New deterministic quality tests prove good fixtures score above risky
  fixtures for all three supported lifts.
- Deadlift back-position and bench elbow-angle rules were corrected after the
  new tests exposed that their previous good/risky fixtures scored identically.
- Annotated feedback now includes the exercise, score, key-frame time, and
  concise stable/attention result directly on the image.
- AI Assistant video feedback now explains auto-detection confidence, key
  metrics, why an all-green result can occur, and the analysis scope.
- Diet Stats no longer overlaps several area/line series. It now shows today's
  nutrition, macro distribution, one calorie trend, and recent records.
- AI Assistant is now the single user entry for training-video form analysis.
- Selecting a video exposes squat/deadlift/bench choice and allows sending
  without a cloud session because pose analysis is local.
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

Important: the production `SESSION_SECRET` changed during repair. Existing
phone sessions are invalid. Users with the old local Apple identity must use the
new reconnect prompt once to receive a new FitGenius cloud session.

## Latest Validation

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
3. Open AI Assistant, choose a 10-30 second squat/deadlift/bench video, select
   the exercise, and tap Send.
4. Confirm that the returned skeleton follows the real body, the key frame is
   useful, and any red highlight matches the detected issue.

This is required because Apple authorization UI and real-device Vision behavior
cannot be fully accepted in Simulator.

## Next Recommended Work

1. Run physical-device acceptance for normalized fitness/diet images and real
   Vision joints using several camera angles.
2. Tune thresholds using a labeled real-video set before claiming broader
   exercise support.
3. Add one new exercise at a time only after defining metrics, risky fixtures,
   and real-device acceptance videos.
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
