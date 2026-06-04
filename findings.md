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

