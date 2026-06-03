import { validateFormAnalysisPayload } from "../backend/formAnalysisPayload.mjs";
import { buildInsertFormAnalysisSQL } from "../backend/formAnalysisRepository.mjs";
import { createExecutor } from "../backend/database.mjs";

export function createFormAnalysesHandler({ executeStatement } = {}) {
  return async function handler(request, response) {
    if (request.method !== "POST") {
      response.setHeader("Allow", "POST");
      response.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const devToken = process.env.FITGENIUS_DEV_SYNC_TOKEN;
    if (devToken) {
      const authorization = request.headers.authorization ?? "";
      if (authorization !== `Bearer ${devToken}`) {
        response.status(401).json({ ok: false, error: "unauthorized" });
        return;
      }
    }

    const payload = request.body;
    const validation = validateFormAnalysisPayload(payload);
    if (!validation.ok) {
      response.status(400).json({ ok: false, error: validation.error });
      return;
    }

    const userId = request.headers["x-fitgenius-user-id"] || "dev-user";
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
