# FitGenius Progress Log

## 2026-06-04

- Confirmed clean `main` baseline at `05c4713`.
- Read `AGENTS.md`, roadmap, handoff, and product-quality plan.
- Audited AI Assistant, local form analysis, pose extraction, rule engine, chat
  persistence, and Stats implementation.
- Agreed product direction: AI Assistant becomes the unified video-coach entry;
  first visual milestone is an annotated representative key frame.
- Added planner tests and observed the expected failure because
  `PoseFeedbackPlanner` did not exist.
- Implemented and passed representative-frame and issue-highlight planning tests.
- Added the local form-analysis pipeline and skeleton overlay renderer.
- Routed AI Assistant videos through local Vision/rules and added exercise choice
  plus bilingual analysis feedback.
- Generic iOS Simulator build succeeded after the AI Assistant integration.
- Simplified training Stats by removing the confusing volume/weight chart pile-up
  from the main flow and adding form-analysis progress and recent findings.
- Added a DEBUG-only launch-video hook so the AI Assistant path can be verified
  end to end with the supplied bench-press video.
- Simulator reached the local analysis path but Apple Vision was unavailable.
  Added a DEBUG-only fixture fallback for UI verification and made annotated
  feedback images large, uncropped, and tappable for full-screen review.
- Simulator verified the annotated image and result message appear in AI
  Assistant. Corrected the full-screen preview to fit the whole frame initially.
- Added recent deterministic form-analysis context to subsequent AI questions.
- Removed the duplicate form-analysis button from training rows so AI Assistant
  is the single user entry for video coaching.
- Final simulator smoke test confirmed duplicate entry removal and a fitted
  full-screen annotated image.
- Updated roadmap, product-quality plan, and agent handoff with the milestone,
  validation evidence, limitations, and next work.
- Prevented new AI video analyses from storing full raw videos in SwiftData chat
  history; only a compressed thumbnail is retained.
- Started the next product-quality milestone after real-user testing exposed
  multimodal AI failures, insufficient scoring evidence, and confusing Diet
  Stats.
- Root cause audit found mislabeled non-JPEG photo data and a missing Diet AI
  cloud-session/reconnect flow.
- Added form-coaching quality tests and observed the expected missing-classifier
  RED state before implementing automatic exercise detection.
- Quality tests exposed that the old deadlift rule scored good and risky
  fixtures identically. Replaced raw torso lean with a shoulder-hip-knee angle
  check that better represents hinge alignment.
- Quality tests then exposed that the old bench rules missed abnormal elbow
  angles. Added an elbow-angle metric and a localized coaching issue.
- Normalized all selected AI images to bounded real JPEG data before sending,
  preventing HEIC/PNG bytes from being mislabeled as JPEG.
- Added Diet AI cloud-session/reconnect UX and a backend regression test proving
  multimodal message content is forwarded unchanged.
- Fixed both AI composers so an attached image can be sent without forcing the
  user to type extra text.
- Made video exercise selection automatic by default, with local pose-based
  classification confidence and a manual override for uncertain camera angles.
- Added a professional feedback-image header and result panel, plus more
  detailed AI text explaining confidence, key metrics, all-green results, and
  the limits of visible-joint analysis.
- Replaced Diet Stats' overlapping macro charts with a readable nutrition
  summary, macro progress rows, a single calorie trend, and recent records.
- XcodeBuildMCP smoke test auto-classified the supplied launch video as bench
  press at 95% confidence and returned a specific highlighted elbow issue.
- Simulator verified the simplified Diet Stats layout and Diet AI reconnect
  banner.
