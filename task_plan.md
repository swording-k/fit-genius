# FitGenius Visible Product Milestone

Last updated: 2026-06-04

## Goal

Turn FitGenius into a reliable, coherent product: repair multimodal AI,
strengthen video-coaching credibility and usability, and simplify both training
and diet statistics around useful decisions.

## Scope

- Keep Apple Vision and the local rule engine as the source of truth.
- Reuse the existing chat, SwiftData history, backend sync, and supported
  exercise rules.
- Keep Android/Huawei paused. Expand form coaching one movement at a time with
  explicit rules and tests.

## Phases

| Phase | Status | Outcome |
|---|---|---|
| 1. Audit current flows | complete | Confirmed AI video upload and local form analysis are disconnected |
| 2. Test feedback planning | complete | Planner test passes for representative frames and highlights |
| 3. Build annotated feedback | complete | Skeleton overlay renderer and local pipeline build successfully |
| 4. Unify AI Assistant flow | complete | Unified entry, local result, annotated frame, and recent-analysis follow-up context |
| 5. Simplify Stats | complete | Removed chart pile-up; added meaningful form progress |
| 6. Validate and hand off | complete | Tests, build, simulator smoke test, and project docs updated |
| 7. Repair multimodal AI | complete | Normalize image data and make cloud-session failures actionable |
| 8. Strengthen form coaching | complete | Auto-detect exercise, validate scoring, improve feedback and overlays |
| 9. Simplify diet Stats | complete | Replace overlapping charts with useful summaries |
| 10. Release-quality regression | in_progress | Full build, backend, simulator, docs, and physical-device checklist |
| 11. Cloud + Watch milestone | complete | Cloud snapshots, account deletion, and Watch companion verified |
| 12. Trustworthy form-coach expansion | complete | Standing overhead press, unsupported-motion rejection, issue callouts, and bounded 4K processing |
| 13. Repair Diet Stats semantics | complete | Merge same-day records, exclude empty days, and use calorie-based macro shares |

## Errors Encountered

| Error | Attempt | Resolution |
|---|---|---|
| Missing `PoseFeedbackPlanner.swift` | 1 | Expected RED state before implementing planner |
| Swift test script rejected top-level expressions | 1 | Added explicit `@main` test entry |
| Apple Vision unavailable in current Simulator | 1 | Added DEBUG-only fixture fallback for visual UI verification; real device still required |
| Missing `FormExerciseClassifier.swift` | 1 | Expected RED state before implementing auto-detection |
