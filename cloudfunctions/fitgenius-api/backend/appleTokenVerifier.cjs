"use strict";

const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_ISSUER = "https://appleid.apple.com";

let _jose = null;
async function getJose() {
  if (!_jose) _jose = await import("jose");
  return _jose;
}

let _jwks = null;
function getJWKS() {
  if (!_jwks) {
    // Will be initialized lazily with createRemoteJWKSet
    _jwks = null;
  }
  return _jwks;
}

async function resolveJWKS() {
  if (_jwks) return _jwks;
  const { createRemoteJWKSet } = await getJose();
  _jwks = createRemoteJWKSet(new URL(APPLE_JWKS_URL), {
    cacheMaxAge: 60 * 60 * 1000
  });
  return _jwks;
}

/**
 * Verifies an Apple identity token and returns the decoded claims.
 * @param {string} identityToken - Apple-issued JWT
 * @returns {Promise<{ sub: string, email?: string, email_verified?: boolean }>}
 */
async function verifyAppleIdentityToken(identityToken) {
  if (typeof identityToken !== "string" || identityToken.length === 0) {
    throw new Error("missing_identity_token");
  }

  const audience = process.env.APPLE_BUNDLE_ID;
  if (!audience) {
    throw new Error("APPLE_BUNDLE_ID not configured");
  }

  const { jwtVerify } = await getJose();
  const jwks = await resolveJWKS();

  const { payload } = await jwtVerify(identityToken, jwks, {
    issuer: APPLE_ISSUER,
    audience,
    algorithms: ["RS256"]
  });

  if (!payload.sub) {
    throw new Error("missing_sub in Apple token");
  }

  return {
    sub: payload.sub,
    email: typeof payload.email === "string" ? payload.email : undefined,
    email_verified: payload.email_verified === "true" || payload.email_verified === true
  };
}

module.exports = { verifyAppleIdentityToken };
