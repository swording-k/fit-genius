# Tutorial batch 2 and release preparation

> **For agentic workers:** Execute the independent media-review tasks in parallel; main agent alone owns browser, catalog and deployments. Check off evidence-backed milestones, never inferred completion.

**Goal:** Expand beyond the 24 reviewed common exercises toward 50 distinct templates, then hand off a verifiable release candidate and concrete remaining publication gates.

**Architecture:** Keep the existing stable template IDs, cloud JSON manifest, CloudBase object-hosted short videos, on-demand cache and Release rights filtering. Do not merge or submit before the owner has reviewed this candidate; no rights status is inferred from a public source.

**Tech Stack:** SwiftUI/SwiftData, Node CloudBase, ffmpeg/ffprobe, canonical exercise GIFs.

## Media acquisition and review

- [x] Read current source inventory, catalog and batch-one review records; preserve user Xcode state and untracked marketing project.
- [x] Download five verified additional official/collaboration sources to ignored `video/tutorial-source/douyin/` using already observed browser assets. Verify audio/video duration with ffprobe.
- [x] Review upper and lower source streams independently. Record accepted variants and rejected mismatches in `docs/tutorial-reviews/batch2-*.json`; use actual canonical GIFs, not names alone. Target 10–30 seconds with complete cycles and bilingual filming hints; never pad with error examples to meet an arbitrary minimum. Explicit same-exercise setup variations must be recorded for owner acceptance.
- [x] Main-agent visual check of approved ranges, then H.264/AAC fast-start encode to ignored `cloud-content/exercise-tutorials/development-media/`; enforce the existing 20 MB asset limit.
- [x] Upload 12 new assets first with `tcb hosting deploy <file> exercise-tutorials/development-media/<file> --env-id fitgenius-d0ghm1rz21cef6594`; only then publish catalog changes.
- [x] Compare all new HTTPS asset bytes/hashes with local files. Run `node scripts/tutorial-source-coverage.mjs` and the Swift remote repository test with `--live` against the final manifest.
- [x] Update `docs/tutorial-batch-acceptance.md` with exact new IDs, names, original ranges and cloud URLs; counts mean distinct playable templates, never unverified candidates. Current: 36, not yet 50.

## Release preparation

- [x] Read-only inspection of real CloudBase routes, client paths, privacy disclosures, account deletion, target versions and Release media packaging. Distinguish confirmed defects from untested physical-device behavior. Findings: `docs/release-candidate-audit-2026-10-03.md`.
- [ ] Fix confirmed in-scope release defects with proportionate verification; capture any external/authentication requirements rather than changing permissions or guessing credentials.
- [ ] Build the candidate, then update `docs/agent-handoff.md` Current Status / Latest Validation / Next Recommended Work. Commit and push this feature branch without merging.
- [ ] Owner verifies the candidate's exercise detail, playback, manual comparison, initial empty plan, authenticated plan proposal and data continuity. Publication requires that acceptance and an explicit authorized-media scope; keep development media hidden otherwise.
