import { createExecutor } from "../backend/database.mjs";
import {
  buildEnsureCloudSnapshotSchemaSQL,
  buildGetCloudSnapshotSQL,
  buildUpsertCloudSnapshotSQL
} from "../backend/cloudSnapshotRepository.mjs";
import { extractBearerToken, verifySessionToken } from "../backend/sessionToken.mjs";

const MAX_SNAPSHOT_BYTES = 2_500_000;
const schemaPromises = new WeakMap();

export function createCloudSnapshotHandler({
  executeStatement,
  verifyToken = verifySessionToken,
  ensureSchema = ensureCloudSnapshotSchema
} = {}) {
  return async function handler(request, response) {
    if (request.method !== "GET" && request.method !== "PUT") {
      response.setHeader("Allow", "GET, PUT");
      response.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const bearer = extractBearerToken(request.headers?.authorization);
    if (!bearer) {
      response.status(401).json({ ok: false, error: "missing_authorization" });
      return;
    }

    let session;
    try {
      session = await verifyToken(bearer);
    } catch {
      response.status(401).json({ ok: false, error: "invalid_session" });
      return;
    }
    if (!executeStatement) {
      response.status(503).json({ ok: false, error: "database_not_configured" });
      return;
    }
    await ensureSchema(executeStatement);

    if (request.method === "GET") {
      const record = await executeStatement(buildGetCloudSnapshotSQL({ userId: session.userId }));
      if (!record) {
        response.status(404).json({ ok: false, error: "snapshot_not_found" });
        return;
      }
      response.status(200).json({ ok: true, snapshot: record.snapshot, updatedAt: record.updated_at });
      return;
    }

    const payload = request.body;
    const validation = validateCloudSnapshot(payload);
    if (!validation.ok) {
      response.status(400).json({ ok: false, error: validation.error });
      return;
    }
    const record = await executeStatement(
      buildUpsertCloudSnapshotSQL({ userId: session.userId, payload })
    );
    response.status(200).json({ ok: true, snapshot: record.snapshot, updatedAt: record.updated_at });
  };
}

export async function ensureCloudSnapshotSchema(executeStatement) {
  let promise = schemaPromises.get(executeStatement);
  if (!promise) {
    promise = executeStatement(buildEnsureCloudSnapshotSchemaSQL()).catch((error) => {
      schemaPromises.delete(executeStatement);
      throw error;
    });
    schemaPromises.set(executeStatement, promise);
  }
  await promise;
}

export function validateCloudSnapshot(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false, error: "invalid_snapshot" };
  }
  if (payload.schemaVersion !== 1) {
    return { ok: false, error: "unsupported_schema_version" };
  }
  if (!Array.isArray(payload.mealDays)) {
    return { ok: false, error: "invalid_meal_days" };
  }
  if (Buffer.byteLength(JSON.stringify(payload), "utf8") > MAX_SNAPSHOT_BYTES) {
    return { ok: false, error: "snapshot_too_large" };
  }
  return { ok: true };
}

export default createCloudSnapshotHandler({ executeStatement: createExecutor() ?? undefined });
