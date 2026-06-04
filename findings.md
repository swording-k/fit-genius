# FitGenius Findings

## 2026-06-04 Product Audit

- The existing AI Assistant sends selected videos to the remote multimodal AI
  service. It does not invoke Apple Vision or the local form-rule engine.
- The existing form-analysis sheet invokes Apple Vision and the local rules, but
  only returns text, score, and metrics.
- `ChatMessage` already supports persisted image data, so annotated feedback can
  be shown in chat without adding a new persistence model.
- `PoseFrame` includes timestamps and joint coordinates. This is enough to
  select a representative frame and draw a skeleton over the source video frame.
- The existing Stats page combines several overlapping charts and does not show
  form-analysis history, despite that being the product's differentiating data.
- Real-device Vision acceptance is still required before release. Simulator and
  command-line validation can verify build, navigation, and deterministic logic.

## 2026-06-04 Multimodal and Scoring Audit

- PhotosPicker data is forwarded unchanged but always labeled
  `data:image/jpeg`; HEIC/PNG input can therefore be rejected by the provider.
- Diet AI does not inspect `AuthViewModel` or present a reconnect flow. An
  expired backend session becomes a generic chat error.
- Backend tests only cover text-shaped `messages`; they do not prove the
  multimodal payload is accepted by the upstream provider.
- Current rule-engine tests do not prove that good fixtures score above risky
  fixtures, and there is no exercise auto-classifier.
- Green overlay means a joint/segment was detected and no mapped issue marked it
  red. It is not proof that every aspect of the lift is correct.
- Diet Stats still overlays several area and line series, making the charts hard
  to interpret.
- Deterministic quality tests now prove score separation for all four supported
  lifts: squat 96/46, deadlift 96/66, bench press 96/76, and standing overhead
  press 96/76 for good/risky fixtures.
- Automatic detection is intentionally limited to the four supported lifts and
  rejects uncertain motion instead of forcing a label.
  Adding more labels without corresponding rules and real-video acceptance
  would make the product appear broader while reducing trust.
- Simulator validation proves the local analysis UI and rule fixtures, but the
  actual pose joints from Apple Vision and real cloud image acceptance still
  require a physical iPhone.
- The supplied bench video is 157 MB and 4K. Full-resolution frame decoding made
  the simulator UI appear unresponsive; bounded extraction/feedback dimensions
  fixed the simulator flow and should reduce physical-device memory/latency.
- Empty `MealDay` rows are created when users merely open Diet. Counting them
  produced fake `0 kcal` history; Diet Stats now filters them out.
- Production multimodal live acceptance cannot be forged from the local
  `/tmp/fitgenius-production.env` because encrypted values pull as empty.
  A real Apple-authenticated phone session is required.
