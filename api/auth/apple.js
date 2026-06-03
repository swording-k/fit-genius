import { verifyAppleIdentityToken } from "../../backend/appleTokenVerifier.mjs";
import { signSessionToken } from "../../backend/sessionToken.mjs";
import { createExecutor } from "../../backend/database.mjs";

export function createAppleAuthHandler({ executeStatement, signToken } = {}) {
  const realSignToken = signToken || signSessionToken;
  const realExecute = executeStatement ?? createExecutor();

  return async function handler(request, response) {
    if (request.method !== "POST") {
      response.setHeader("Allow", "POST");
      response.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const { identityToken, fullName, userIdentifier } = request.body ?? {};
    if (typeof identityToken !== "string" || identityToken.length === 0) {
      response.status(400).json({ ok: false, error: "missing_identity_token" });
      return;
    }
    if (typeof userIdentifier !== "string" || userIdentifier.length === 0) {
      response.status(400).json({ ok: false, error: "missing_user_identifier" });
      return;
    }

    const verification = await verifyAppleIdentityToken({ identityToken });
    if (!verification.ok) {
      response.status(401).json({ ok: false, error: verification.error });
      return;
    }

    if (verification.appleUserId !== userIdentifier) {
      response.status(401).json({ ok: false, error: "user_identifier_mismatch" });
      return;
    }

    const userId = `usr_${verification.appleUserId}`;
    const displayName = composeDisplayName(fullName);

    if (!realExecute) {
      // Validated-only path: the iOS client can still get a session token
      // when DATABASE_URL is missing so login flow can be exercised in dev.
      const { token, expiresAt } = await realSignToken({
        userId,
        appleUserIdentifier: verification.appleUserId
      });
      response.status(200).json({
        ok: true,
        mode: "validated_only",
        sessionToken: token,
        userId,
        expiresAt,
        displayName
      });
      return;
    }

    await upsertUser({
      execute: realExecute,
      userId,
      appleUserIdentifier: verification.appleUserId,
      displayName,
      email: verification.email
    });

    const { token, expiresAt } = await realSignToken({
      userId,
      appleUserIdentifier: verification.appleUserId
    });
    response.status(200).json({
      ok: true,
      mode: "stored",
      sessionToken: token,
      userId,
      expiresAt,
      displayName
    });
  };
}

function composeDisplayName(fullName) {
  if (!fullName || typeof fullName !== "object") return undefined;
  const given = typeof fullName.givenName === "string" ? fullName.givenName.trim() : "";
  const family = typeof fullName.familyName === "string" ? fullName.familyName.trim() : "";
  const composed = [given, family].filter((s) => s.length > 0).join(" ").trim();
  return composed.length > 0 ? composed : undefined;
}

async function upsertUser({ execute, userId, appleUserIdentifier, displayName, email }) {
  const statement = {
    text: `
      insert into users (id, apple_user_identifier, display_name, email)
      values ($1, $2, $3, $4)
      on conflict (id) do update set
        apple_user_identifier = excluded.apple_user_identifier,
        display_name = coalesce(excluded.display_name, users.display_name),
        email = coalesce(excluded.email, users.email),
        updated_at = now()
      returning id, display_name, email;
    `,
    values: [userId, appleUserIdentifier, displayName ?? null, email ?? null]
  };
  await execute(statement);
}

export default createAppleAuthHandler();
