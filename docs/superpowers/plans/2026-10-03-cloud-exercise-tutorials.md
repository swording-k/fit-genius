# Cloud Exercise Tutorials Implementation Plan

**Goal:** Collect traceable Tan Sir sources and make tutorials updateable without shipping another App binary.

**Architecture:** CloudBase Hosting stores the versioned JSON catalog; HTTPS cloud storage/CDN hosts playable media. The App caches the last valid catalog and falls back to bundled development metadata. A research inventory is separate from the published catalog: candidate matches never silently become reviewed tutorials.

**Tech Stack:** SwiftUI, Foundation URLSession, CloudBase Hosting, JSON, ffmpeg.

## Tasks

- [x] Record verified official-profile sources in `docs/tutorial-sources/douyin-tan.json`; preserve stable exercise IDs and mark mappings as candidates until footage is reviewed.
- [x] Add `scripts/tutorial-source-coverage.mjs` to report every exercise's research coverage without asserting missing-source absence.
- [x] Add failing async regression checks in `scripts/exercise-tutorial-remote-tests.swift`: valid remote update, last-good disk cache, rejected invalid schema/HTTP URL, empty-catalog removal, and Release development-media filtering.
- [x] Add `ExerciseTutorialRepository.swift` (validated remote fetch and atomic disk cache) and `ExerciseTutorialStore.swift` (shared observable UI state). Update the shared learning surface to refresh nonblockingly.
- [x] Publish reviewed source links and two Debug-only excerpts to the scoped `exercise-tutorials` prefix; verify actual HTTPS JSON. Research candidates are not published as playable media.
- [x] Run repository tests, existing tutorial tests, source inventory audit, and unsigned simulator build. Record exact coverage and unresolved clip-review work in handoff.
- [x] Investigate gateway Range behavior; implement and test selected-excerpt caching instead of changing bucket ACLs. Production CDN/domain configuration remains separate work.
- [ ] Continue research and exact-variant review across the remaining 1300 unreviewed exercise templates.

## Media workflow

Original files remain under ignored `video/tutorial-source/douyin/<sourceVideoID>.mp4`. A published playable record requires reviewed timestamps, exact exercise variant, camera framing, and a stable HTTPS asset URL (not Douyin's expiring media URL). Existing development-only binaries stay out of Release. Until a reviewed hosted excerpt exists, a verified source may be an `externalLinkOnly` entry; the App must not imply side-by-side playback is available for it.
