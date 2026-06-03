import assert from "node:assert/strict";
import { generateKeyPair, exportJWK, SignJWT, jwtVerify } from "jose";
import {
  verifyAppleIdentityToken,
  __setAppleJWKSLoader
} from "../appleTokenVerifier.mjs";

const originalAudience = process.env.APPLE_BUNDLE_ID;

async function makeFixture({ overrides = {} } = {}) {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const kid = "test-kid-" + Math.random().toString(36).slice(2);
  const jwk = await exportJWK(publicKey);
  jwk.kid = kid;
  jwk.alg = "RS256";
  jwk.use = "sig";

  const loader = createInlineJWKSLoader({ [kid]: jwk });
  __setAppleJWKSLoader(loader);

  const appleUserId = "001234.deadbeef.5678";
  const payload = {
    iss: "https://appleid.apple.com",
    aud: process.env.APPLE_BUNDLE_ID,
    exp: Math.floor(Date.now() / 1000) + 600,
    iat: Math.floor(Date.now() / 1000),
    sub: appleUserId,
    email: "user@example.com",
    email_verified: "true",
    ...overrides
  };
  const token = await new SignJWT(payload)
    .setProtectedHeader({ alg: "RS256", kid, typ: "JWT" })
    .sign(privateKey);
  return { token, appleUserId, kid, publicKey };
}

function createInlineJWKSLoader(keys) {
  return async function localJWKS(header) {
    if (!header || !header.kid) throw new Error("missing_kid");
    const key = keys[header.kid];
    if (!key) throw new Error("kid_not_found");
    return (await import("jose")).importJWK(key, "RS256");
  };
}

try {
  process.env.APPLE_BUNDLE_ID = "com.swordingk.fitgenius";

  const happy = await makeFixture();
  const ok = await verifyAppleIdentityToken({ identityToken: happy.token });
  assert.equal(ok.ok, true);
  assert.equal(ok.appleUserId, happy.appleUserId);
  assert.equal(ok.email, "user@example.com");
  assert.equal(ok.emailVerified, true);

  const noAud = await makeFixture({ overrides: { aud: "wrong.bundle.id" } });
  const fail = await verifyAppleIdentityToken({ identityToken: noAud.token });
  assert.equal(fail.ok, false);
  assert.match(fail.error, /^verification_failed:/);

  const noIssuer = await makeFixture({ overrides: { iss: "https://evil.example.com" } });
  const failIssuer = await verifyAppleIdentityToken({ identityToken: noIssuer.token });
  assert.equal(failIssuer.ok, false);

  const empty = await verifyAppleIdentityToken({ identityToken: "" });
  assert.equal(empty.ok, false);
  assert.equal(empty.error, "missing_identity_token");

  const noBundle = await verifyAppleIdentityToken({ identityToken: "any.token.value" });
  // The loader is now the test loader; only the audience check should run.
  assert.equal(noBundle.ok, false);
  assert.match(noBundle.error, /^verification_failed:/);

  console.log("appleTokenVerifier tests passed");
} finally {
  if (originalAudience === undefined) {
    delete process.env.APPLE_BUNDLE_ID;
  } else {
    process.env.APPLE_BUNDLE_ID = originalAudience;
  }
  __setAppleJWKSLoader(null);
}
