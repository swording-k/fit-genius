"use strict";

const DEFAULT_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

let _jose = null;
async function getJose() {
  if (!_jose) _jose = await import("jose");
  return _jose;
}

function getSecret() {
  const secret = process.env.SESSION_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error("SESSION_SECRET is not set or is shorter than 32 characters.");
  }
  return new TextEncoder().encode(secret);
}

function getIssuer() {
  return process.env.SESSION_ISSUER || "fitgenius";
}

/**
 * Signs a session JWT. In validated-only mode, uses sub as userId.
 * @param {{ sub: string, email?: string, name?: object }} params
 */
async function signSessionToken({ sub, email, name } = {}) {
  if (!sub) throw new Error("signSessionToken: sub is required");
  const { SignJWT } = await getJose();
  const nowSeconds = Math.floor(Date.now() / 1000);
  const expSeconds = nowSeconds + DEFAULT_TTL_SECONDS;
  const token = await new SignJWT({
    sub: sub,
    apple_sub: sub,
    email: email || "",
    name: name || {}
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
 */
async function verifySessionToken(token) {
  if (!token) throw new Error("verifySessionToken: token is required");
  const { jwtVerify } = await getJose();
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
 * Extracts Bearer token from Authorization header.
 */
function extractBearerToken(authorizationHeader) {
  if (typeof authorizationHeader !== "string") return null;
  const [scheme, value] = authorizationHeader.split(" ");
  if (!scheme || !value) return null;
  if (scheme.toLowerCase() !== "bearer") return null;
  return value.trim();
}

module.exports = { signSessionToken, verifySessionToken, extractBearerToken };
