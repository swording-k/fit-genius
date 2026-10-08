# Common-exercise Tutorial Batch 3 Implementation Plan

> **For agentic workers:** Continue inline with independent media review workers; unavailable superpowers execution skills are not assumed.

**Goal:** Expand the 36-template cloud catalog with additional visually verified common movements.

**Architecture:** Keep existing stable template-ID metadata and on-demand CloudBase media. Publish encoded assets before the manifest; preserve prior mappings and development-only filtering. No App behavior or release-status change.

**Tech Stack:** Swift catalog loader, JSON metadata, ffmpeg/ffprobe, CloudBase Hosting.

## Tasks

- [x] Review existing chest/arms, back/shoulder, legs/core sources independently; record exact ranges and rejected mismatches in `docs/tutorial-reviews/batch3-*.json`.
- [x] Inspect additional official-profile sources through observed browser media assets where downloaded material does not cover gaps.
- [x] Main agent compares proposed source frames with canonical GIFs and checks full correct repetition, equipment, grip, posture and bilingual filming hints.
- [x] Encode approved 9–30-second excerpts (0321 stops before the counterexample) as H.264/AAC with faststart; ffprobe duration/codec and 20 MiB limit.
- [x] Add only approved distinct IDs to `cloud-content/exercise-tutorials/catalog-v1.json` and provenance to `docs/tutorial-sources/douyin-tan.json` via apply_patch.
- [x] Deploy individual MP4s, verify full HTTPS bytes against local SHA-256, then publish and verify manifest.
- [x] Run `node scripts/tutorial-source-coverage.mjs`, `node scripts/tutorial-catalog-audit-tests.mjs` and compiled remote catalog test with `--live`. No repeated App build unless source code changes.
- [x] Update acceptance list and handoff Current Status / Latest Validation / Next Recommended Work; commit/push only scoped metadata/docs, keep user scheme and unrelated video project untouched.

Missing exact matches stay blank. Backups do not increase distinct coverage. Complete originals remain ignored; temporary files with no later review use are removed.
