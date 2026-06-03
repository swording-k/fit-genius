import assert from "node:assert/strict";
import { buildInsertFormAnalysisSQL } from "../formAnalysisRepository.mjs";

const payload = {
  schemaVersion: 1,
  localIdentifier: "form-1780000000000-bench_press-x",
  analyzedAt: "2026-06-02T12:00:00.000Z",
  exerciseName: "卧推'); drop table users; --",
  exerciseType: "bench_press",
  score: 96,
  issues: [],
  metrics: [{ key: "pose_quality", label: "识别质量", value: 0.979, unit: "0-1" }],
  recommendation: "动作整体稳定，可以保持当前重量。",
  videoDuration: 15.77,
  sourcePlatform: "ios"
};

const statement = buildInsertFormAnalysisSQL({
  userId: "dev-user",
  payload
});

assert.equal(statement.values.length, 12);
assert.equal(statement.values[4], "卧推'); drop table users; --");
assert.equal(statement.values[5], "bench_press");
assert.equal(statement.values[8], 96);
assert.equal(statement.text.includes("drop table"), false);
assert.equal(statement.text.includes("$1"), true);
assert.equal(statement.text.includes("on conflict"), true);

console.log("formAnalysisRepository tests passed");
