import assert from "node:assert/strict";
import handler, { createFormAnalysesHandler } from "../../api/form-analyses.js";

const validPayload = {
  schemaVersion: 1,
  localIdentifier: "form-1780000000000-bench_press-x",
  analyzedAt: "2026-06-02T12:00:00.000Z",
  exerciseName: "卧推",
  exerciseType: "bench_press",
  score: 96,
  issues: [],
  metrics: [{ key: "pose_quality", label: "识别质量", value: 0.979, unit: "0-1" }],
  recommendation: "动作整体稳定，可以保持当前重量。",
  videoDuration: 15.77,
  sourcePlatform: "ios"
};

const originalDevToken = process.env.FITGENIUS_DEV_SYNC_TOKEN;
const originalDatabaseURL = process.env.DATABASE_URL;

try {
  delete process.env.FITGENIUS_DEV_SYNC_TOKEN;
  delete process.env.DATABASE_URL;

  const methodResponse = await invoke({ method: "GET", headers: {}, body: validPayload });
  assert.equal(methodResponse.statusCode, 405);
  assert.equal(methodResponse.headers.Allow, "POST");

  process.env.FITGENIUS_DEV_SYNC_TOKEN = "dev-token";
  const unauthorizedResponse = await invoke({ method: "POST", headers: {}, body: validPayload });
  assert.equal(unauthorizedResponse.statusCode, 401);
  assert.deepEqual(unauthorizedResponse.body, { ok: false, error: "unauthorized" });

  const invalidPayloadResponse = await invoke({
    method: "POST",
    headers: { authorization: "Bearer dev-token" },
    body: { ...validPayload, score: -1 }
  });
  assert.equal(invalidPayloadResponse.statusCode, 400);
  assert.equal(invalidPayloadResponse.body.error, "score must be an integer from 0 to 100");

  const acceptedResponse = await invoke({
    method: "POST",
    headers: {
      authorization: "Bearer dev-token",
      "x-fitgenius-user-id": "user-1"
    },
    body: validPayload
  });
  assert.equal(acceptedResponse.statusCode, 202);
  assert.deepEqual(acceptedResponse.body, {
    ok: true,
    mode: "validated_only",
    localIdentifier: validPayload.localIdentifier
  });

  process.env.DATABASE_URL = "postgres://example.invalid/fitgenius";
  let capturedStatement;
  const databaseHandler = createFormAnalysesHandler({
    executeStatement: async (statement) => {
      capturedStatement = statement;
      return {
        id: "record-1",
        local_identifier: validPayload.localIdentifier,
        updated_at: "2026-06-02T12:00:00.000Z"
      };
    }
  });
  const databaseResponse = await invoke({
    method: "POST",
    headers: {
      authorization: "Bearer dev-token",
      "x-fitgenius-user-id": "user-1"
    },
    body: validPayload
  }, databaseHandler);
  assert.equal(databaseResponse.statusCode, 200);
  assert.equal(databaseResponse.body.ok, true);
  assert.equal(databaseResponse.body.mode, "stored");
  assert.equal(databaseResponse.body.localIdentifier, validPayload.localIdentifier);
  assert.equal(capturedStatement.values[0], "user-1");

  console.log("formAnalysesApi tests passed");
} finally {
  restoreEnv("FITGENIUS_DEV_SYNC_TOKEN", originalDevToken);
  restoreEnv("DATABASE_URL", originalDatabaseURL);
}

async function invoke(request, targetHandler = handler) {
  const response = createResponse();
  await targetHandler(request, response);
  return response.result;
}

function createResponse() {
  const result = {
    statusCode: 200,
    headers: {},
    body: undefined
  };

  return {
    result,
    setHeader(name, value) {
      result.headers[name] = value;
      return this;
    },
    status(code) {
      result.statusCode = code;
      return this;
    },
    json(body) {
      result.body = body;
      return this;
    }
  };
}

function restoreEnv(name, value) {
  if (value === undefined) {
    delete process.env[name];
  } else {
    process.env[name] = value;
  }
}
