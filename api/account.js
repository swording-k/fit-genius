import { createExecutor } from "../backend/database.mjs";
import { extractBearerToken, verifySessionToken } from "../backend/sessionToken.mjs";

export function createAccountHandler({ executeStatement, verifyToken = verifySessionToken } = {}) {
  return async function handler(request, response) {
    if (request.method !== "DELETE") {
      response.setHeader("Allow", "DELETE");
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

    const record = await executeStatement({
      text: "delete from users where id = $1 returning id;",
      values: [session.userId]
    });
    response.status(200).json({ ok: true, deleted: Boolean(record) });
  };
}

export default createAccountHandler({ executeStatement: createExecutor() ?? undefined });
