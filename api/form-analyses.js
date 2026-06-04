import { validateFormAnalysisPayload } from "../backend/formAnalysisPayload.mjs";
import { buildInsertFormAnalysisSQL } from "../backend/formAnalysisRepository.mjs";
import { createExecutor } from "../backend/database.mjs";
import { extractBearerToken, verifySessionToken } from "../backend/sessionToken.mjs";

export function createFormAnalysesHandler({ executeStatement, verifyToken = verifySessionToken } = {}) {
  return async function handler(request, response) {
    if (request.method !== "POST") {
      response.setHeader("Allow", "POST");
      response.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const bearer = extractBearerToken(request.headers.authorization);
    if (!bearer) {
      response.status(401).json({ ok: false, error: "missing_authorization" });
      return;
    }

    let userId;
    const devToken = process.env.FITGENIUS_DEV_SYNC_TOKEN;
    if (devToken && bearer === devToken) {
      userId = request.headers["x-fitgenius-user-id"] || "dev-user";
    } else {
      try {
        const session = await verifyToken(bearer);
        userId = session.userId;
      } catch {
        response.status(401).json({ ok: false, error: "invalid_session" });
        return;
      }
    }

    const payload = request.body;
    const validation = validateFormAnalysisPayload(payload);
    if (!validation.ok) {
      response.status(400).json({ ok: false, error: validation.error });
      return;
    }

    const statement = buildInsertFormAnalysisSQL({ userId, payload });

    if (!process.env.DATABASE_URL) {
      response.status(202).json({
        ok: true,
        mode: "validated_only",
        localIdentifier: payload.localIdentifier
      });
      return;
    }

    if (!executeStatement) {
      response.status(501).json({
        ok: false,
        error: "database_client_not_configured",
        statementName: "insert_form_analysis_record",
        parameterCount: statement.values.length
      });
      return;
    }

    const storedRecord = await executeStatement(statement);
    response.status(200).json({
      ok: true,
      mode: "stored",
      id: storedRecord.id,
      localIdentifier: storedRecord.local_identifier,
      updatedAt: storedRecord.updated_at
    });
  };
}

export default createFormAnalysesHandler({ executeStatement: createExecutor() ?? undefined });
