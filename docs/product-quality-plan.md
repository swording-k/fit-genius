# FitGenius Product Quality Plan

Last updated: 2026-06-04

## Goal

FitGenius must first become a complete, understandable, and reliable iPhone
product. New platform work starts only after the main user journeys meet the
quality gates below.

## Product Architecture In Plain Language

- The iPhone app owns the user interface, offline training data, local video
  pose extraction, and local form-analysis rules.
- Vercel is the secure online gateway. It verifies Apple login, calls the AI
  provider without exposing its key, and receives cloud-sync requests.
- Neon is the cloud database behind Vercel. It stores users, form-analysis
  history, and account snapshots for profile, workout, and diet continuity.
- Apple Watch assists during a workout. It does not analyze video.

## Quality Gates

### P0: Core Journeys Must Work

- Onboarding creates a usable plan without raw localization keys.
- Training plan actions are clear and do not lose data.
- Apple login clearly distinguishes local identity from cloud connection.
- AI chat opens at the latest message and gives actionable connection errors.
- AI Assistant is the single entry for squat, deadlift, and bench video
  analysis and returns understandable annotated feedback.
- Stats never show raw keys, misleading charts, or duplicated empty states.
- No developer-only controls are visible to users.
- Reset Data requires confirmation and actually removes all local product data.
- Delete Account is reachable, confirmed, and deletes cloud data before local
  cleanup.

### P1: Product Coherence

- Audit every screen in Chinese and English.
- Standardize navigation, empty states, loading, errors, and destructive actions.
- Make AI history manageable with conversation/session organization.
- Tune form-analysis history and trends in Stats with real-device data.
- Verify training, diet, widget, notifications, account deletion, and sync on a
  physical iPhone.

### P2: Release Readiness

- Run simulator smoke tests and physical-device acceptance tests.
- Validate offline behavior and failed-network recovery.
- Verify privacy text, permissions, App Store metadata, and account deletion.
- Archive and upload a TestFlight build for product review.

### P3: Expansion

- Validate and refine the implemented Apple Watch companion after the iPhone
  P0-P2 gates pass.
- Start Android/Huawei work only after the iOS form-coach loop proves useful.

## Current Release Blockers

- A physical iPhone must reconnect Apple login once because the production
  session secret was repaired on 2026-06-04.
- AI chat and video analysis need one real-device acceptance pass with that new
  session.
- Remaining screens still need a full bilingual UX audit.
- Apple Watch MVP is implemented but requires paired-watch acceptance and is
  not on the current iPhone release critical path.
