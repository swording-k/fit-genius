# FitGenius Android Client Plan

Last updated: 2026-06-12

## Goal

Build a first Android client for FitGenius as the same product experience as
the iOS app, while keeping the existing iOS project stable and untouched.

The Android app is not a direct copy of the SwiftUI code. It is a native
Android client that reuses the product structure, backend, AI proxy, cloud
sync concepts, and form-coach pose schema.

## Scope For The First Android Build

Included:

- Training tab with today's workout and exercise progress.
- Diet tab with meal cards and calories/protein/carbs/fat summaries.
- AI Assistant tab with text-first coaching UI and media-entry placeholders.
- Form Coach tab for Android-side pose analysis planning.
- Local offline state so the app is useful before login.
- Backend configuration surface for the existing Vercel API base URL.
- Bilingual UI strings for Chinese and English.
- A buildable APK from the `android/` folder.

Deferred:

- Android widgets.
- Wear OS / Huawei watch features.
- Google Play / AppGallery release automation.
- HarmonyOS NEXT native client.
- Full Health Connect integration.
- Broad exercise expansion beyond the current iOS-supported form-coach set.

## Architecture

The Android client is isolated under `android/`:

```text
android/
  settings.gradle.kts
  build.gradle.kts
  app/
    build.gradle.kts
    src/main/
      AndroidManifest.xml
      java/com/swordingk/fitgenius/
      res/values/
      res/values-zh-rCN/
    src/test/
```

The first implementation uses:

- Kotlin.
- Jetpack Compose.
- Material 3.
- JVM unit tests for product logic.
- Android local state first, backend sync later.

The Android client must not introduce provider API keys. AI requests must go
through the existing `/api/ai/chat` backend proxy once login/session plumbing is
implemented.

## Product Parity Rules

- Android should feel like FitGenius, not a separate simplified brand.
- iOS remains the source of truth for current shipped behavior.
- If a feature is incomplete on Android, show an honest empty/coming-soon state
  instead of pretending it works.
- User-facing text must be localized in English and Simplified Chinese.
- Form analysis on Android should use MediaPipe Pose Landmarker to produce the
  same platform-neutral pose data (`PoseFrame`, `JointPoint`, `FormIssue`) used
  by the iOS rules.

## Current Milestone

Create the Android project, build a stable app shell, and verify a debug APK can
be produced locally.

## Next Recommended Work

1. Install JDK and Android SDK tooling on this Mac.
2. Create the Android Gradle project under `android/`.
3. Add data models and tests for nutrition and workout progress.
4. Add the Compose app shell and four product tabs.
5. Build `assembleDebug` and archive the generated APK path in
   `docs/agent-handoff.md`.
