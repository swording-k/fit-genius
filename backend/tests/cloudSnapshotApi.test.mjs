import assert from "node:assert/strict";
import test from "node:test";
import {
  createCloudSnapshotHandler,
  ensureCloudSnapshotSchema,
  validateCloudSnapshot
} from "../../api/cloud-snapshot.js";
import { buildEnsureCloudSnapshotSchemaSQL } from "../cloudSnapshotRepository.mjs";

const snapshot = { schemaVersion: 1, profile: null, workoutPlan: null, mealDays: [] };

test("cloud snapshot validation accepts the v1 shape", () => {
  assert.deepEqual(validateCloudSnapshot(snapshot), { ok: true });
  assert.equal(validateCloudSnapshot({ schemaVersion: 2, mealDays: [] }).ok, false);
  assert.equal(validateCloudSnapshot({ schemaVersion: 1 }).ok, false);
});

test("cloud snapshot lazy schema references the users primary key", () => {
  assert.match(buildEnsureCloudSnapshotSchemaSQL().text, /references users\(id\)/i);
});

test("cloud snapshot handler stores an authenticated snapshot", async () => {
  let statement;
  const handler = createCloudSnapshotHandler({
    verifyToken: async () => ({ userId: "user-1" }),
    ensureSchema: async () => {},
    executeStatement: async (value) => {
      statement = value;
      return { snapshot, updated_at: "2026-06-04T08:00:00Z" };
    }
  });
  const response = await invoke(handler, {
    method: "PUT",
    headers: { authorization: "Bearer valid" },
    body: snapshot
  });
  assert.equal(response.statusCode, 200);
  assert.equal(statement.values[0], "user-1");
  assert.equal(statement.values[1], 1);
});

test("cloud snapshot handler returns 404 when none exists", async () => {
  const handler = createCloudSnapshotHandler({
    verifyToken: async () => ({ userId: "user-1" }),
    ensureSchema: async () => {},
    executeStatement: async () => null
  });
  const response = await invoke(handler, {
    method: "GET",
    headers: { authorization: "Bearer valid" }
  });
  assert.equal(response.statusCode, 404);
});

test("cloud snapshot handler rejects missing auth", async () => {
  const handler = createCloudSnapshotHandler({ executeStatement: async () => null });
  const response = await invoke(handler, { method: "GET", headers: {} });
  assert.equal(response.statusCode, 401);
});

test("cloud snapshot handler ensures schema after authentication", async () => {
  let ensured = false;
  const handler = createCloudSnapshotHandler({
    verifyToken: async () => ({ userId: "user-1" }),
    ensureSchema: async () => { ensured = true; },
    executeStatement: async () => null
  });
  await invoke(handler, {
    method: "GET",
    headers: { authorization: "Bearer valid" }
  });
  assert.equal(ensured, true);
});

test("cloud snapshot lazy schema retries after a transient failure", async () => {
  let attempts = 0;
  const execute = async () => {
    attempts += 1;
    if (attempts === 1) throw new Error("temporary");
    return null;
  };
  await assert.rejects(ensureCloudSnapshotSchema(execute));
  await ensureCloudSnapshotSchema(execute);
  assert.equal(attempts, 2);
});

async function invoke(handler, request) {
  const result = {
    statusCode: 200,
    headers: {},
    body: null,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
  await handler(request, result);
  return result;
}
