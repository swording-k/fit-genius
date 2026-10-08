# Release Repair Implementation Plan

> Execute inline with independent AI/backend/local-cleanup workers. Unavailable
> superpowers execution skills are not assumed. Keep the existing feature branch.

**Goal:** Deliver a buildable release candidate with diagnosed data/AI/account blockers fixed.

**Architecture:** SwiftData remains primary. Explicit sync decisions prevent empty
draft overwrite. Authenticated immutable chunk uploads publish only complete
snapshots; legacy small requests remain compatible. Errors preserve user data.

**Tech Stack:** SwiftData, SwiftUI, URLSession, CryptoKit, CloudBase Node18, node:test.

## Tasks

- [x] AI worker: reproduce missing-session and parsing fallback; replace silent
  fallback with thrown localized errors in AIService; run real behavior tests.
- [x] Main: add SwiftData/URLProtocol regressions for empty draft, manual days,
  HTTP500/invalid JSON no-write, account switch and pending edits. Run red,
  fix CloudSnapshotModels/Coordinator, then run green.
- [x] Backend worker: implement tested legacy/chunk snapshot and account deletion
  in cloudfunctions/fitgenius-api; initialize account generation/revocation and
  keep all data queries scoped to authenticated user. Run node:test red/green.
- [x] Main: implement CloudSnapshotWireClient; test real URLSession serialization
  for large UTF8 payload, <=100KB each request, partial acknowledgment and corrupt
  downloads. Wire CloudSnapshotService only after tests fail on old behavior.
- [x] Local cleanup worker: test all14 product models, reference-template
  preservation and deletion failure; connect sync suspension around deletion.
- [x] Main: deploy tested function code without overwriting production env,
  create only required new collections and DELETE route. Verify health plus
  missing/invalid-session boundaries; do not delete real user records.
- [x] Main: inspect build evidence, align target versions and perform unsigned
  Simulator build plus signed Release Archive when current provisioning permits.
  Validate embedded plist versions and absence of development media in Release.
- [x] Main: run focused regressions, localization/secret checks and review workers'
  diffs; record exact source/tests/cloud/build/device evidence in handoff and
  release acceptance list. Scoped commit/push; no merge or Store submission.

Commands: `node --test cloudfunctions/fitgenius-api/tests/*.test.cjs`,
`scripts/run-release-repair-tests.sh`, `scripts/check-localization.sh`,
`xcodebuild -project FitGenius.xcodeproj -scheme FitGenius -destination
'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`, `git diff --check`.
