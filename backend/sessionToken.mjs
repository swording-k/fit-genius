import { SignJWT, jwtVerify } from "jose";

const DEFAULT_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

function getSecret() {
  const secret = process.env.SESSION_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error(
      "SESSION_SECRET is not set or is shorter than 32 characters. " +
        "Generate one with `openssl rand -hex 32` before deploying."
    );
  }
  return new TextEncoder().encode(secret);
}

function getIssuer() {
  return process.env.SESSION_ISSUER || "fitgenius";
}

/**
 * Signs a session JWT for an authenticated FitGenius user.
 *
 * @param {object} params
 * @param {string} params.userId The internal user id (matches `users.id`).
 * @param {string} params.appleUserIdentifier The Apple-issued user id (sub claim).
 * @param {number} [params.ttlSeconds] Optional override for testability.
 * @returns {Promise<{ token: string, expiresAt: number }>}
 */
export async function signSessionToken({ userId, appleUserIdentifier, ttlSeconds = DEFAULT_TTL_SECONDS } = {}) {
  if (!userId || !appleUserIdentifier) {
    throw new Error("signSessionToken: userId and appleUserIdentifier are required");
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  const expSeconds = nowSeconds + ttlSeconds;
  const token = await new SignJWT({
    sub: userId,
    apple_sub: appleUserIdentifier
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setIssuer(getIssuer())
    .setIssuedAt(nowSeconds)
    .setExpirationTime(expSeconds)
    .sign(getSecret());
  return { token, expiresAt: expSeconds };
}

/**
 * Verifies a session JWT and returns its claims.
 *
 * @param {string} token
 * @returns {Promise<{ userId: string, appleUserIdentifier: string, expiresAt: number }>}
 */
export async function verifySessionToken(token) {
  if (!token) {
    throw new Error("verifySessionToken: token is required");
  }
  const { payload } = await jwtVerify(token, getSecret(), {
    issuer: getIssuer(),
    algorithms: ["HS256"]
  });
  if (!payload.sub || !payload.apple_sub) {
    throw new Error("verifySessionToken: missing required claims");
  }
  return {
    userId: payload.sub,
    appleUserIdentifier: payload.apple_sub,
    expiresAt: payload.exp
  };
}

/**
 * Extracts a Bearer token from an `Authorization: Bearer xxx` header value.
 * Returns `null` when the header is missing or malformed.
 */
export function extractBearerToken(authorizationHeader) {
  if (typeof authorizationHeader !== "string") return null;
  const [scheme, value] = authorizationHeader.split(" ");
  if (!scheme || !value) return null;
  if (scheme.toLowerCase() !== "bearer") return null;
  return value.trim();
}
