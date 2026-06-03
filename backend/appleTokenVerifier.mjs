import { jwtVerify, createRemoteJWKSet } from "jose";

const APPLE_JWKS_URL = new URL("https://appleid.apple.com/auth/keys");
const APPLE_ISSUER = "https://appleid.apple.com";

/**
 * Cache that maps a JWK `kid` to its resolved key. Replace this in tests.
 */
let jwksCache = null;

function resolveJWKS() {
  // The chosen caching strategy lives in `loadAppleJWKS` below.
  // Tests can override the cache by assigning a custom function here:
  //   import { __setAppleJWKSLoader } from "./appleTokenVerifier.mjs";
  //   __setAppleJWKSLoader(customLoader);
  return loadAppleJWKS();
}

/**
 * Returns a function that resolves an Apple JWK by `kid`. See the
 * human-contribution point below for the caching strategy.
 *
 * The returned function should be:
 *   async (kid) => { return KeyLike | Uint8Array }
 * and throw when the kid cannot be resolved.
 */
function loadAppleJWKS() {
  // Strategy: jose's built-in caching.
  // - Auto-dedupes concurrent fetches for the same `kid`.
  // - Auto-refreshes the key when cacheMaxAge expires (1 hour).
  // - 1h TTL keeps the impact of an Apple key rotation window to <= 1h.
  return createRemoteJWKSet(APPLE_JWKS_URL, {
    cacheMaxAge: 60 * 60 * 1000
  });
}

export function __setAppleJWKSLoader(loader) {
  jwksCache = loader;
}

function getJWKSLoader() {
  if (jwksCache) return jwksCache;
  jwksCache = loadAppleJWKS();
  return jwksCache;
}

/**
 * Verifies an Apple identity token and returns the claims required to
 * upsert a FitGenius user.
 *
 * @param {object} params
 * @param {string} params.identityToken Apple-issued JWT (compact serialization).
 * @param {string} [params.expectedAudience] Optional `aud` override; defaults
 *   to `APPLE_BUNDLE_ID` from the environment.
 * @returns {Promise<{ ok: true, appleUserId: string, email?: string, emailVerified?: boolean } | { ok: false, error: string }>}
 */
export async function verifyAppleIdentityToken({ identityToken, expectedAudience } = {}) {
  if (typeof identityToken !== "string" || identityToken.length === 0) {
    return { ok: false, error: "missing_identity_token" };
  }
  const audience = expectedAudience || process.env.APPLE_BUNDLE_ID;
  if (!audience) {
    return { ok: false, error: "missing_audience" };
  }
  const loader = getJWKSLoader();
  try {
    const { payload } = await jwtVerify(identityToken, loader, {
      issuer: APPLE_ISSUER,
      audience,
      algorithms: ["RS256"]
    });
    if (!payload.sub) {
      return { ok: false, error: "missing_sub" };
    }
    return {
      ok: true,
      appleUserId: payload.sub,
      email: typeof payload.email === "string" ? payload.email : undefined,
      emailVerified: payload.email_verified === "true" || payload.email_verified === true
    };
  } catch (error) {
    return { ok: false, error: `verification_failed:${error.code || error.name || "unknown"}` };
  }
}
