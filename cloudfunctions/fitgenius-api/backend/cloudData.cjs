"use strict";
const { createHash, randomUUID } = require("node:crypto");
const CHUNK_BYTES = 48 * 1024;
const MAX_CHUNKS = 512;
// Existing released clients still send direct JSON between 64 and 96 KiB.
// New clients choose chunks earlier, but the server preserves that old contract.
const INLINE_BYTES = 96 * 1024;
const hash = value => createHash("sha256").update(value).digest("hex");
function fail(status, error) { const e = new Error(error); e.httpStatus = status; e.errorCode = error; throw e; }
function first(result) { const data = result?.data; return Array.isArray(data) ? data[0] : data || null; }
const stateID = user => hash(user);
const snapshotID = user => `snapshot-${hash(user)}`;
const chunkID = (user, generation, id, index) => hash(JSON.stringify([user, generation, id, index]));

function createCloudData(db) {
  const transaction = callback => db.runTransaction(callback);
  async function state(store, user) { return first(await store.collection("account_states").doc(stateID(user)).get()); }
  async function authorize(claims, store = db) {
    const current = await state(store, claims.userId);
    if (current && (current.status !== "active" || (claims.generation || "0") !== current.generation)) fail(401, "revoked_session");
    if (!current && (claims.generation || "0") !== "0") fail(401, "revoked_session");
    return current;
  }
  async function guardWrite(claims, tx) {
    const current = await authorize(claims, tx);
    const ref = tx.collection("account_states").doc(stateID(claims.userId));
    // Snapshot-isolation reads alone do not lock the state. A real revision
    // write forces conflicts with deletion, so retries see its revoked state.
    if (current) await ref.update({ writeRevision: (current.writeRevision || 0) + 1 });
    else await ref.set({ generation: "0", status: "active", writeRevision: 1 });
  }
  async function loginGeneration(user) {
    return transaction(async tx => {
      const current = await state(tx, user);
      // No eager creation: legacy sessions and simultaneous first logins share 0.
      if (!current) return "0";
      if (current.status === "deleting") fail(503, "account_deletion_pending");
      if (current.status === "active") return current.generation;
      const generation = randomUUID();
      await tx.collection("account_states").doc(stateID(user)).set({ generation, status: "active" });
      return generation;
    });
  }
  async function deleteAccount(claims) {
    let deletionStage = "begin";
    try {
    const alreadyDeleted = await transaction(async tx => {
      const current = await state(tx, claims.userId);
      const generation = claims.generation || "0";
      if (current && current.status !== "active" && current.deletedGeneration === generation) return current.status === "deleted";
      await authorize(claims, tx);
      await tx.collection("account_states").doc(stateID(claims.userId)).set({
        generation: randomUUID(), deletedGeneration: generation,
        status: "deleting", deletedAt: new Date().toISOString()
      });
      return false;
    });
    if (alreadyDeleted) return { ok: true, deleted: true };
    for (const name of ["form_analyses", "cloud_snapshots", "cloud_snapshot_chunks"]) {
      for (;;) {
        deletionStage = `query.${name}`;
        const docs = (await db.collection(name).where({ userId: claims.userId }).limit(100).get()).data || [];
        if (!docs.length) break;
        for (let offset = 0; offset < docs.length; offset += 16) {
          deletionStage = `remove.${name}`;
          const finished = await transaction(async tx => {
            const current = await state(tx, claims.userId);
            if (current?.deletedGeneration !== (claims.generation || "0") || current.status === "active") fail(401, "revoked_session");
            if (current.status === "deleted") return true;
            await tx.collection("account_states").doc(stateID(claims.userId)).update({ writeRevision: (current.writeRevision || 0) + 1 });
            // A transaction is one server-side session, not a parallel request
            // batch. Concurrent removes can abort it with TRANSACTION_FAIL.
            for (const doc of docs.slice(offset, offset + 16)) {
              await tx.collection(name).doc(doc._id).remove();
            }
            return false;
          });
          if (finished) return { ok: true, deleted: true };
        }
      }
    }
    deletionStage = "complete";
    await transaction(async tx => {
      const current = await state(tx, claims.userId);
      if (current?.deletedGeneration !== (claims.generation || "0") || current.status === "active") fail(401, "revoked_session");
      await tx.collection("account_states").doc(stateID(claims.userId)).update({ status: "deleted" });
    });
    return { ok: true, deleted: true };
    } catch (error) {
      error.deletionStage = deletionStage;
      throw error;
    }
  }
  async function writeAnalysis(claims, body) {
    // Account state and write share a transaction: deletion cannot race a write.
    return transaction(async tx => {
      await guardWrite(claims, tx);
      const id = randomUUID();
      await tx.collection("form_analyses").doc(id).set({ userId: claims.userId, createdAt: new Date().toISOString(), payload: body });
      return id;
    });
  }
  async function findSnapshot(user) {
    const canonical = first(await db.collection("cloud_snapshots").doc(snapshotID(user)).get());
    if (canonical) return canonical;
    return first(await db.collection("cloud_snapshots").where({ userId: user }).limit(1).get());
  }
  async function publish(claims, snapshot, snapshotDownload, updatedAt) {
    const previous = await transaction(async tx => {
      await guardWrite(claims, tx);
      const current = first(await tx.collection("cloud_snapshots").doc(snapshotID(claims.userId)).get());
      if (snapshotDownload) {
        const descriptor = tx.collection("cloud_snapshot_chunks").doc(chunkID(claims.userId, claims.generation || "0", snapshotDownload.id, "manifest"));
        const meta = first(await descriptor.get());
        if (meta?.committed) {
          if (current?.snapshotDownload?.id !== snapshotDownload.id) fail(409, "snapshot_version_changed");
          return;
        }
        await descriptor.update({ committed: true });
      }
      // Deterministic doc ID eliminates duplicate first-upload races. Legacy rows
      // remain readable until this pointer is committed, then are superseded.
      await tx.collection("cloud_snapshots").doc(snapshotID(claims.userId)).set({
        userId: claims.userId, ...(snapshotDownload ? { snapshotDownload, generation: claims.generation || "0" } : { snapshot }), updatedAt
      });
      return current;
    });
    if (previous?.snapshotDownload && previous.snapshotDownload.id !== snapshotDownload?.id) {
      // The old revision is no longer addressable. Reclaim only its binary
      // chunks, keep its tiny committed descriptor to reject delayed replay.
      try {
        for (let offset = 0; offset < previous.snapshotDownload.count; offset += 16) {
          await Promise.all(Array.from({ length: Math.min(16, previous.snapshotDownload.count - offset) }, (_, n) => db.collection("cloud_snapshot_chunks").doc(chunkID(claims.userId, previous.generation, previous.snapshotDownload.id, offset + n)).remove()));
        }
      } catch { /* A committed snapshot must not become a failed upload on cleanup failure. */ }
    }
  }
  async function upload(claims, body) {
    if (!body || typeof body !== "object" || Array.isArray(body)) fail(400, "invalid_body");
    const updatedAt = new Date().toISOString();
    if (!Object.prototype.hasOwnProperty.call(body, "snapshotUpload")) {
      if (Buffer.byteLength(JSON.stringify(body)) > INLINE_BYTES) fail(413, "snapshot_requires_chunks");
      await publish(claims, body, null, updatedAt);
      return { ok: true, snapshot: body, updatedAt };
    }
    if (!body.snapshotUpload || typeof body.snapshotUpload !== "object" || Array.isArray(body.snapshotUpload)) fail(400, "invalid_snapshot_chunk");
    const { id, index, count, chunk } = body.snapshotUpload;
    if (typeof id !== "string" || !/^[a-zA-Z0-9_-]{1,100}$/.test(id) || !Number.isInteger(index) || !Number.isInteger(count) || count < 1 || count > MAX_CHUNKS || index < 0 || index >= count || typeof chunk !== "string" || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(chunk)) fail(400, "invalid_snapshot_chunk");
    const bytes = Buffer.from(chunk, "base64");
    if (!bytes.length || bytes.length > CHUNK_BYTES || bytes.toString("base64") !== chunk) fail(400, "invalid_snapshot_chunk");
    const generation = claims.generation || "0";
    const ready = await transaction(async tx => {
      await guardWrite(claims, tx);
      const ref = tx.collection("cloud_snapshot_chunks").doc(chunkID(claims.userId, generation, id, index));
      const old = first(await ref.get());
      if (old && (old.count !== count || old.chunk !== chunk)) fail(409, "snapshot_upload_conflict");
      // A descriptor ensures differing counts conflict even at different indices.
      const descriptor = tx.collection("cloud_snapshot_chunks").doc(chunkID(claims.userId, generation, id, "manifest"));
      const meta = first(await descriptor.get());
      if (meta && meta.count !== count) fail(409, "snapshot_upload_conflict");
      if (meta?.committed && !old) fail(409, "snapshot_version_changed");
      if (!old) await ref.set({ userId: claims.userId, generation, uploadID: id, index, count, chunk, createdAt: updatedAt });
      const received = meta?.received || [];
      if (!received.includes(index)) received.push(index);
      await descriptor.set({ userId: claims.userId, generation, uploadID: id, count, received, committed: meta?.committed || false, createdAt: meta?.createdAt || updatedAt });
      return received.length === count;
    });
    if (!ready) return { ok: true, snapshotUpload: { id, index, count, complete: false } };
    const parts = [];
    for (let offset = 0; offset < count; offset += 16) {
      const group = await Promise.all(Array.from({ length: Math.min(16, count - offset) }, (_, n) => db.collection("cloud_snapshot_chunks").doc(chunkID(claims.userId, generation, id, offset + n)).get()));
      parts.push(...group.map(first));
    }
    if (parts.some(part => !part)) return { ok: true, snapshotUpload: { id, index, count, complete: false } };
    const full = Buffer.concat(parts.map(part => Buffer.from(part.chunk, "base64")));
    let snapshot;
    try { snapshot = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(full)); } catch { fail(400, "invalid_snapshot_json"); }
    if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot)) fail(400, "invalid_snapshot_json");
    const snapshotDownload = { id, count, sha256: hash(full) };
    await publish(claims, null, snapshotDownload, updatedAt);
    return { ok: true, snapshotUpload: { id, index, count, complete: true }, updatedAt };
  }
  async function download(claims, query = {}) {
    const doc = await findSnapshot(claims.userId);
    if (!doc) fail(404, "not_found");
    let metadata = doc.snapshotDownload;
    let legacyBytes;
    if (!metadata && doc.snapshot) {
      legacyBytes = Buffer.from(JSON.stringify(doc.snapshot));
      if (legacyBytes.length > INLINE_BYTES) metadata = { id: hash(legacyBytes), count: Math.ceil(legacyBytes.length / CHUNK_BYTES), sha256: hash(legacyBytes) };
    }
    if (query.chunk !== undefined) {
      if (!metadata) fail(409, "snapshot_version_changed");
      const index = Number(query.chunk);
      if (query.download !== metadata.id) fail(409, "snapshot_version_changed");
      if (!/^\d+$/.test(String(query.chunk)) || !Number.isInteger(index) || index < 0 || index >= metadata.count) fail(400, "invalid_chunk_index");
      let chunk;
      if (legacyBytes) chunk = legacyBytes.subarray(index * CHUNK_BYTES, (index + 1) * CHUNK_BYTES).toString("base64");
      else {
        const part = first(await db.collection("cloud_snapshot_chunks").doc(chunkID(claims.userId, doc.generation, metadata.id, index)).get());
        if (!part || part.count !== metadata.count) fail(500, "snapshot_chunk_missing");
        chunk = part.chunk;
      }
      return { ok: true, snapshotChunk: { id: metadata.id, index, count: metadata.count, chunk } };
    }
    return { ok: true, ...(metadata ? { snapshotDownload: metadata } : { snapshot: doc.snapshot }), updatedAt: doc.updatedAt };
  }
  return { authorize, loginGeneration, deleteAccount, writeAnalysis, upload, download };
}
module.exports = { createCloudData };
