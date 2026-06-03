import assert from "node:assert/strict";
import { generateKeyPair, exportJWK, SignJWT } from "jose";
import { createAppleAuthHandler } from "../../api/auth/apple.js";
import { __setAppleJWKSLoader } from "../appleTokenVerifier.mjs";

const originalBundleId = process.env.APPLE_BUNDLE_ID;
const originalSecret = process.env.SESSION_SECRET;
const originalIssuer = process.env.SESSION_ISSUER;

async function buildAppleToken(appleUserId) {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const kid = "auth-test-kid";
  const jwk = await exportJWK(publicKey);
  jwk.kid = kid;
  jwk.alg = "RS256";
  jwk.use = "sig";
  __setAppleJWKSLoader(async (header) => {
    if (header?.kid !== kid) throw new Error("kid_not_found");
    return (await import("jose")).importJWK(jwk, "RS256");
  });
  return await new SignJWT({
    iss: "https://appleid.apple.com",
    aud: process.env.APPLE_BUNDLE_ID,
    exp: Math.floor(Date.now() / 1000) + 600,
    iat: Math.floor(Date.now() / 1000),
    sub: appleUserId,
    email: "user@example.com",
    email_verified: "true"
  })
    .setProtectedHeader({ alg: "RS256", kid, typ: "JWT" })
    .sign(privateKey);
}

try {
  process.env.APPLE_BUNDLE_ID = "com.swordingk.fitgenius";
  process.env.SESSION_SECRET = "x".repeat(32);
  delete process.env.SESSION_ISSUER;

  // Storage-path: success.
  const token1 = await buildAppleToken("001.test-user-a");
  let capturedStatement;
  const handler = createAppleAuthHandler({
    executeStatement: async (statement) => {
      capturedStatement = statement;
      return { id: "usr_001.test-user-a" };
    }
  });

  const okResponse = await invoke(handler, {
    method: "POST",
    body: {
      identityToken: token1,
      userIdentifier: "001.test-user-a",
      fullName: { givenName: "Ada", familyName: "Lovelace" }
    }
  });
  assert.equal(okResponse.statusCode, 200);
  assert.equal(okResponse.body.ok, true);
  assert.equal(okResponse.body.mode, "stored");
  assert.equal(okResponse.body.userId, "usr_001.test-user-a");
  assert.equal(okResponse.body.displayName, "Ada Lovelace");
  assert.equal(typeof okResponse.body.sessionToken, "string");
  assert.equal(typeof okResponse.body.expiresAt, "number");
  assert.ok(capturedStatement, "executor should have been called");
  assert.match(capturedStatement.text, /insert into users/);
  assert.equal(capturedStatement.values[0], "usr_001.test-user-a");
  assert.equal(capturedStatement.values[1], "001.test-user-a");

  // Method check.
  const methodResponse = await invoke(handler, { method: "GET", body: {} });
  assert.equal(methodResponse.statusCode, 405);

  // Missing body fields.
  const noToken = await invoke(handler, { method: "POST", body: { userIdentifier: "x" } });
  assert.equal(noToken.statusCode, 400);
  assert.equal(noToken.body.error, "missing_identity_token");

  const noUserId = await invoke(handler, { method: "POST", body: { identityToken: "any" } });
  assert.equal(noUserId.statusCode, 400);
  assert.equal(noUserId.body.error, "missing_user_identifier");

  // User-identifier mismatch.
  const token2 = await buildAppleToken("001.test-user-b");
  const mismatch = await invoke(handler, {
    method: "POST",
    body: { identityToken: token2, userIdentifier: "001.test-user-c" }
  });
  assert.equal(mismatch.statusCode, 401);
  assert.equal(mismatch.body.error, "user_identifier_mismatch");

  // Validated-only path: no executor injected.
  const token3 = await buildAppleToken("001.test-user-d");
  const noDbHandler = createAppleAuthHandler();
  const validatedResponse = await invoke(noDbHandler, {
    method: "POST",
    body: { identityToken: token3, userIdentifier: "001.test-user-d" }
  });
  assert.equal(validatedResponse.statusCode, 200);
  assert.equal(validatedResponse.body.mode, "validated_only");
  assert.equal(validatedResponse.body.userId, "usr_001.test-user-d");

  console.log("appleAuthApi tests passed");
} finally {
  if (originalBundleId === undefined) delete process.env.APPLE_BUNDLE_ID;
  else process.env.APPLE_BUNDLE_ID = originalBundleId;
  if (originalSecret === undefined) delete process.env.SESSION_SECRET;
  else process.env.SESSION_SECRET = originalSecret;
  if (originalIssuer === undefined) delete process.env.SESSION_ISSUER;
  else process.env.SESSION_ISSUER = originalIssuer;
  __setAppleJWKSLoader(null);
}

async function invoke(targetHandler, request) {
  const response = createResponse();
  await targetHandler(request, response);
  return response.result;
}

function createResponse() {
  const result = { statusCode: 200, headers: {}, body: undefined };
  return {
    result,
    setHeader(name, value) {
      result.headers[name] = value;
      return this;
    },
    status(code) {
      result.statusCode = code;
      return this;
    },
    json(body) {
      result.body = body;
      return this;
    }
  };
}
