import assert from "node:assert/strict";
import { jwtVerify } from "jose";
import { signSessionToken, verifySessionToken, extractBearerToken } from "../sessionToken.mjs";

const originalSecret = process.env.SESSION_SECRET;
const originalIssuer = process.env.SESSION_ISSUER;

try {
  process.env.SESSION_SECRET = "a".repeat(32);
  delete process.env.SESSION_ISSUER;

  const { token, expiresAt } = await signSessionToken({
    userId: "usr_abc",
    appleUserIdentifier: "001234.deadbeef.5678"
  });
  assert.equal(typeof token, "string");
  assert.equal(token.split(".").length, 3);
  assert.ok(expiresAt > Math.floor(Date.now() / 1000));

  const claims = await verifySessionToken(token);
  assert.equal(claims.userId, "usr_abc");
  assert.equal(claims.appleUserIdentifier, "001234.deadbeef.5678");
  assert.equal(claims.expiresAt, expiresAt);

  // Tamper the signature: decode -> re-encode with a different signing key.
  const { payload } = await jwtVerify(token, new TextEncoder().encode("b".repeat(32)), {
    issuer: "fitgenius",
    algorithms: ["HS256"]
  }).catch((err) => ({ payload: null, err }));
  assert.equal(payload, null, "verifySessionToken should reject tokens signed with a different secret");

  // Bearer extraction
  assert.equal(extractBearerToken("Bearer abc.def.ghi"), "abc.def.ghi");
  assert.equal(extractBearerToken("bearer xyz"), "xyz");
  assert.equal(extractBearerToken(undefined), null);
  assert.equal(extractBearerToken(""), null);
  assert.equal(extractBearerToken("Basic abc"), null);
  // "Bearer " with no value is malformed; we return null so callers can 401.
  assert.equal(extractBearerToken("Bearer "), null);

  // Short secret should throw on sign
  const originalSecretShort = process.env.SESSION_SECRET;
  process.env.SESSION_SECRET = "too-short";
  await assert.rejects(
    () => signSessionToken({ userId: "u", appleUserIdentifier: "s" }),
    /SESSION_SECRET/
  );
  process.env.SESSION_SECRET = originalSecretShort;

  console.log("sessionToken tests passed");
} finally {
  if (originalSecret === undefined) {
    delete process.env.SESSION_SECRET;
  } else {
    process.env.SESSION_SECRET = originalSecret;
  }
  if (originalIssuer === undefined) {
    delete process.env.SESSION_ISSUER;
  } else {
    process.env.SESSION_ISSUER = originalIssuer;
  }
}
