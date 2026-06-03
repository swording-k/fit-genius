import assert from "node:assert/strict";
import { validateFormAnalysisPayload } from "../formAnalysisPayload.mjs";

const validPayload = {
  schemaVersion: 1,
  localIdentifier: "form-1780000000000-bench_press-x",
  analyzedAt: "2026-06-02T12:00:00.000Z",
  exerciseName: "卧推",
  exerciseType: "bench_press",
  score: 96,
  issues: [],
  metrics: [
    {
      key: "pose_quality",
      label: "识别质量",
      value: 0.979,
      unit: "0-1"
    }
  ],
  recommendation: "动作整体稳定，可以保持当前重量。",
  videoDuration: 15.77,
  sourcePlatform: "ios"
};

assert.equal(validateFormAnalysisPayload(validPayload).ok, true);

const localizedExerciseType = {
  ...validPayload,
  exerciseType: "卧推"
};
assert.deepEqual(validateFormAnalysisPayload(localizedExerciseType), {
  ok: false,
  error: "exerciseType must be one of squat, deadlift, bench_press"
});

const unsafeScore = {
  ...validPayload,
  score: 101
};
assert.deepEqual(validateFormAnalysisPayload(unsafeScore), {
  ok: false,
  error: "score must be an integer from 0 to 100"
});

const badMetric = {
  ...validPayload,
  metrics: [{ key: "pose_quality", value: "high", unit: "0-1" }]
};
assert.deepEqual(validateFormAnalysisPayload(badMetric), {
  ok: false,
  error: "metrics must contain key, label, numeric value, and unit"
});

console.log("formAnalysisPayload tests passed");
