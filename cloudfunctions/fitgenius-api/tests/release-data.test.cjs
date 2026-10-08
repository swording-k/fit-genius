"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const Module = require("node:module");
const crypto = require("node:crypto");
process.env.SESSION_SECRET = "unit-test-only-not-a-production-secret-000000";
const tables = new Map();
let nextID = 0;
let failRemoveOnce = false;
let failGetOnce = false;
let transactionQueue = Promise.resolve();
function collection(name) {
  if (!tables.has(name)) tables.set(name, new Map());
  const rows = tables.get(name);
  return {
    async add(value) { const id = String(++nextID); rows.set(id, { ...value, _id: id }); return { id }; },
    doc(id) { return {
      async get() { if (failGetOnce) { failGetOnce = false; throw new Error("DB unavailable"); } return { data: rows.has(id) ? [structuredClone(rows.get(id))] : [] }; },
      async set(value) { if (value._id) throw new Error("SDK forbids setting _id"); rows.set(id, { ...structuredClone(value), _id: id }); },
      async update(value) { rows.set(id, { ...rows.get(id), ...structuredClone(value), _id: id }); },
      async remove() { if (failRemoveOnce) { failRemoveOnce = false; throw new Error("DB unavailable"); } rows.delete(id); }
    }; },
    where(query) { const matching = () => [...rows.values()].filter(v => Object.entries(query).every(([k, x]) => v[k] === x)); return {
      limit(n) { return { async get() { return { data: structuredClone(matching().slice(0, n)) }; } }; },
      async get() { return { data: structuredClone(matching()) }; }
    }; }
  };
}
const load = Module._load;
const db = { collection, runTransaction(callback) {
  const result = transactionQueue.then(async () => {
    const backup = structuredClone(tables);
    let writes = 0;
    const transactionCollection = name => {
      const coll = collection(name);
      return { ...coll, doc(id) {
        const doc = coll.doc(id);
        return { ...doc, async remove() {
          if (writes) { const error = new Error("Concurrent operations within one transaction are not supported"); error.code = "DATABASE_TRANSACTION_FAIL"; throw error; }
          writes++;
          try { await Promise.resolve(); return await doc.remove(); }
          finally { writes--; }
        } };
      } };
    };
    try { return await callback({ collection: transactionCollection }); }
    catch (error) { tables.clear(); for (const [k, v] of backup) tables.set(k, v); throw error; }
  });
  transactionQueue = result.catch(() => {});
  return result;
} };
Module._load = function (name, ...args) {
  if (name === "@cloudbase/node-sdk") return { init: () => ({ database: () => db }) };
  return load.call(this, name, ...args);
};
const { main } = require("../index.js");
Module._load = load;
const { signSessionToken } = require("../backend/sessionToken.cjs");
async function request(method, body, token, query = {}, path = "/api/cloud-snapshot") {
  const res = await main({ httpMethod: method, path, headers: token ? { authorization: `Bearer ${token}` } : {}, body: body && JSON.stringify(body), queryStringParameters: query });
  return { status: res.statusCode, ...JSON.parse(res.body) };
}
test.beforeEach(async () => { await transactionQueue; tables.clear(); failRemoveOnce = false; failGetOnce = false; });
test("account deletion requires authentication and accepts stripped DELETE gateway route", async () => {
  assert.equal((await request("DELETE", null, null, {}, "/")).status, 401);
  const { token } = await signSessionToken({ sub: "alice" });
  await collection("form_analyses").add({ userId: "alice" });
  await collection("form_analyses").add({ userId: "bob" });
  await collection("cloud_snapshot_chunks").add({ userId: "alice" });
  await collection("cloud_snapshot_chunks").add({ userId: "bob" });
  await request("PUT", { plan: "old" }, token);
  assert.equal((await request("DELETE", null, token, {}, "/")).status, 200);
  assert.equal((await collection("form_analyses").where({ userId: "alice" }).get()).data.length, 0);
  assert.equal((await collection("form_analyses").where({ userId: "bob" }).get()).data.length, 1);
  assert.equal((await collection("cloud_snapshots").where({ userId: "alice" }).get()).data.length, 0);
  assert.equal((await collection("cloud_snapshot_chunks").where({ userId: "alice" }).get()).data.length, 0);
  assert.equal((await collection("cloud_snapshot_chunks").where({ userId: "bob" }).get()).data.length, 1);
  assert.equal((await request("PUT", { plan: "resurrect" }, token)).status, 401);
  assert.equal((await request("DELETE", null, token, {}, "/api/account")).status, 200);
});
test("partial large upload preserves previous snapshot; full upload is chunked and isolated", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  const bob = await signSessionToken({ sub: "bob" });
  await request("PUT", { plan: "old" }, token);
  const snapshot = { schemaVersion: 2, notes: "健身💪".repeat(17000) };
  const bytes = Buffer.from(JSON.stringify(snapshot));
  const count = Math.ceil(bytes.length / (48 * 1024));
  for (let index = 0; index < count; index++) {
    const envelope = { snapshotUpload: { id: "upload-alice-01", index, count, chunk: bytes.subarray(index * 48 * 1024, (index + 1) * 48 * 1024).toString("base64") } };
    const result = await request("PUT", envelope, token);
    assert.equal(result.status, 200);
    assert.equal(result.snapshotUpload.complete, index === count - 1);
    if (index === 0) assert.deepEqual((await request("GET", null, token)).snapshot, { plan: "old" });
  }
  const metadata = await request("GET", null, token);
  assert.equal(metadata.snapshotDownload.count, count);
  assert.equal(metadata.snapshotDownload.sha256, crypto.createHash("sha256").update(bytes).digest("hex"));
  const chunks = [];
  for (let index = 0; index < count; index++) {
    const res = await request("GET", null, token, { download: metadata.snapshotDownload.id, chunk: String(index) });
    assert.equal(res.status, 200);
    chunks.push(Buffer.from(res.snapshotChunk.chunk, "base64"));
  }
  assert.deepEqual(JSON.parse(Buffer.concat(chunks)), snapshot);
  assert.equal((await request("GET", null, bob.token, { download: metadata.snapshotDownload.id, chunk: "0" })).status, 404);
  assert.equal((await request("GET", null, token, { download: "different-version", chunk: "0" })).status, 409);
});
test("failed deletion is retryable; Apple relogin gets one new generation and old JWT stays revoked", async () => {
  const service = require("../backend/cloudData.cjs").createCloudData(db);
  const { token } = await signSessionToken({ sub: "alice" });
  await request("PUT", { plan: "old" }, token);
  failRemoveOnce = true;
  const failed = await request("DELETE", null, token, {}, "/api/account");
  assert.equal(failed.status, 500);
  assert.equal(failed.diagnostic.stage, "remove.cloud_snapshots");
  assert.deepEqual(Object.keys(failed.diagnostic).sort(), ["code", "stage", "type"]);
  await assert.rejects(service.loginGeneration("alice"), /account_deletion_pending/);
  assert.equal((await request("PUT", { plan: "resurrect" }, token)).status, 401);
  assert.equal((await request("DELETE", null, token, {}, "/api/account")).status, 200);
  const [one, two] = await Promise.all([service.loginGeneration("alice"), service.loginGeneration("alice")]);
  assert.equal(one, two);
  assert.notEqual(one, "0");
  const fresh = await signSessionToken({ sub: "alice", generation: one });
  assert.equal((await request("PUT", { plan: "fresh" }, fresh.token)).status, 200);
  assert.equal((await request("DELETE", null, token, {}, "/api/account")).status, 401);
  assert.deepEqual((await request("GET", null, fresh.token)).snapshot, { plan: "fresh" });
});
test("conflicting chunk counts and bytes are rejected, completed upload retry cannot replace newer snapshot", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  const value = { id: "retry-id", index: 0, count: 1, chunk: Buffer.from('{"plan":"first"}').toString("base64") };
  assert.equal((await request("PUT", { snapshotUpload: value }, token)).snapshotUpload.complete, true);
  assert.equal((await request("PUT", { snapshotUpload: { ...value, count: 2, index: 1 } }, token)).status, 409);
  assert.equal((await request("PUT", { snapshotUpload: { ...value, chunk: Buffer.from("{}").toString("base64") } }, token)).status, 409);
  await request("PUT", { plan: "newer" }, token);
  assert.equal((await request("PUT", { snapshotUpload: value }, token)).status, 409);
  assert.deepEqual((await request("GET", null, token)).snapshot, { plan: "newer" });
});
test("bad chunk payloads cannot overwrite a valid snapshot", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  await request("PUT", { plan: "old" }, token);
  for (const value of [
    null,
    false,
    "invalid",
    { id: "id", index: -1, count: 1, chunk: "e30=" },
    { id: "id", index: 0, count: 513, chunk: "e30=" },
    { id: "id", index: 0, count: 1, chunk: "not-base64" },
    { id: "id", index: 0, count: 1, chunk: Buffer.alloc(49153).toString("base64") },
    { id: "id", index: 0, count: 1, chunk: Buffer.from("invalid JSON").toString("base64") }
  ]) assert.equal((await request("PUT", { snapshotUpload: value }, token)).status, 400);
  assert.deepEqual((await request("GET", null, token)).snapshot, { plan: "old" });
});
test("database outage is retryable server failure, not an expired session", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  failGetOnce = true;
  assert.equal((await request("GET", null, token)).status, 503);
});
test("legacy large stored snapshot is downloadable without new upload", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  const snapshot = { plan: "legacy", notes: "a".repeat(250000) };
  await collection("cloud_snapshots").add({ userId: "alice", snapshot, updatedAt: "old" });
  const meta = await request("GET", null, token);
  assert.equal(meta.snapshotDownload.count, 6);
  const pieces = [];
  for (let index = 0; index < meta.snapshotDownload.count; index++) {
    const res = await request("GET", null, token, { download: meta.snapshotDownload.id, chunk: String(index) });
    pieces.push(Buffer.from(res.snapshotChunk.chunk, "base64"));
  }
  assert.deepEqual(JSON.parse(Buffer.concat(pieces)), snapshot);
});
test("out-of-order chunks, exact 48KiB boundary and maximum count are accepted", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  const bytes = Buffer.from(JSON.stringify({ notes: "a".repeat(49160) }));
  for (const index of [1, 0]) {
    const result = await request("PUT", { snapshotUpload: { id: "out-of-order", index, count: 2, chunk: bytes.subarray(index * 49152, (index + 1) * 49152).toString("base64") } }, token);
    assert.equal(result.status, 200);
    assert.equal(result.snapshotUpload.complete, index === 0);
  }
  const result = await request("PUT", { snapshotUpload: { id: "maximum-count", index: 511, count: 512, chunk: "e30=" } }, token);
  assert.equal(result.status, 200);
  assert.equal(result.snapshotUpload.complete, false);
});
test("replacing committed large snapshot reclaims its binary chunks but retains anti-replay descriptor", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  const value = { id: "reclaim-id", index: 0, count: 1, chunk: Buffer.from('{"plan":"first"}').toString("base64") };
  await request("PUT", { snapshotUpload: value }, token);
  await request("PUT", { plan: "newer" }, token);
  const rows = (await collection("cloud_snapshot_chunks").where({ userId: "alice" }).get()).data;
  assert.equal(rows.length, 1);
  assert.equal(rows[0].committed, true);
  assert.equal(rows[0].chunk, undefined);
  assert.equal((await request("PUT", { snapshotUpload: value }, token)).status, 409);
});
test("already completed deletion retry returns without opening a new destructive cleanup window", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  await request("DELETE", null, token, {}, "/api/account");
  // A retained row inserted after completion must not be touched by an old
  // idempotent retry. This exposes the race with a newly authenticated session.
  await collection("form_analyses").add({ userId: "alice", payload: "new" });
  assert.equal((await request("DELETE", null, token, {}, "/api/account")).status, 200);
  assert.equal((await collection("form_analyses").where({ userId: "alice" }).get()).data.length, 1);
});
test("snapshot writes modify account-state revision to acquire a write conflict with deletion", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  await request("PUT", { plan: "first" }, token);
  const stateID = crypto.createHash("sha256").update("alice").digest("hex");
  const one = (await collection("account_states").doc(stateID).get()).data[0];
  assert.equal(one?.writeRevision, 1);
  await request("PUT", { plan: "second" }, token);
  assert.equal((await collection("account_states").doc(stateID).get()).data[0].writeRevision, 2);
});
test("legacy 70KiB JSON snapshots keep their direct upload/download contract", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  const snapshot = { notes: "a".repeat(70 * 1024) };
  const result = await request("PUT", snapshot, token);
  assert.equal(result.status, 200);
  assert.deepEqual(result.snapshot, snapshot);
  assert.deepEqual((await request("GET", null, token)).snapshot, snapshot);
});
test("account deletion serializes multiple chunk removes inside one transaction", async () => {
  const { token } = await signSessionToken({ sub: "alice" });
  for (let n = 0; n < 5; n++) await collection("cloud_snapshot_chunks").add({ userId: "alice", index: n });
  const result = await request("DELETE", null, token, {}, "/api/account");
  assert.equal(result.status, 200);
  assert.equal((await collection("cloud_snapshot_chunks").where({ userId: "alice" }).get()).data.length, 0);
});
