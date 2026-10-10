# Tutorial Discovery Implementation Plan

**Goal:** Make existing playable tutorials discoverable and review additional common-exercise sources.

**Architecture:** ExerciseTutorialCatalog derives playable template IDs after build visibility filtering; ExerciseLibraryView observes the shared remote store and intersects this set with search/body/equipment results. No database migration or media-rights change.

**Tech Stack:** SwiftUI, SwiftData, Codable, CloudBase HTTPS catalog.

Execution is inline; user has authorized implementation without another design-review pause.

- [x] Add `scripts/tutorial-discovery-tests.swift`, compile with ExerciseTutorialClip and ExerciseTutorialCatalog. Assert unique playable IDs, exclusion of link-only/missing local assets/invalid entries, and Debug/Release counts. Watch failure before adding the property.
- [x] Add `playableTemplateIDs` to ExerciseTutorialCatalog using validated clips with a resolved playback URL; exclude externalLinkOnly.
- [x] Observe ExerciseTutorialStore in ExerciseLibraryView; add tutorial-only chip with total available count, row badge, filtered result count, refresh on library entry, and contextual empty-state reset.
- [x] Add matching zh-Hans/en strings; compile focused tests and lint strings.
- [x] Build signed Debug device app; install on available owner device without resetting data. Record installation separately from manual UI acceptance.
- [x] Inspect new source footage against canonical GIFs, publish only verified new variants, and retain evidence or explain concrete unresolved access/matching limits.
- [x] Update handoff Current Status / Latest Validation / Next Recommended Work and push scoped changes on the existing unmerged feature branch.
