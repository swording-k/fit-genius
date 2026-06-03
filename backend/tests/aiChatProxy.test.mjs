import assert from "node:assert/strict";
import { signSessionToken } from "../sessionToken.mjs";
import { createAIChatHandler } from "../../api/ai/chat.js";

const originalSecret = process.env.SESSION_SECRET;
const originalIssuer = process.env.SESSION_ISSUER;
const originalKey = process.env.ALIYUN_API_KEY;

try {
  process.env.SESSION_SECRET = "z".repeat(32);
  delete process.env.SESSION_ISSUER;
  process.env.ALIYUN_API_KEY = "test-aliyun-key";

  const { token } = await signSessionToken({
    userId: "usr_ai",
    appleUserIdentifier: "001.ai"
  });

  // Build a fake fetch that records the call and returns a fake upstream.
  let captured = null;
  const fakeFetch = async (url, init) => {
    captured = { url, init };
    return new Response(JSON.stringify({ id: "chatcmpl-1", choices: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
  };
  const handler = createAIChatHandler({ fetchImpl: fakeFetch });

  // Happy path.
  const ok = await invoke(handler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }], model: "qwen-test" }
  });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.body.ok, true);
  assert.match(captured.url, /dashscope\.aliyuncs\.com\/compatible-mode\/v1\/chat\/completions/);
  assert.match(captured.init.headers.Authorization, /^Bearer test-aliyun-key/);
  const sentBody = JSON.parse(captured.init.body);
  assert.equal(sentBody.model, "qwen-test");
  assert.equal(sentBody.messages[0].role, "user");
  assert.equal(sentBody.stream, false);

  // Missing auth.
  const noAuth = await invoke(handler, { method: "POST", body: { messages: [] } });
  assert.equal(noAuth.statusCode, 401);

  // Wrong method.
  const wrongMethod = await invoke(handler, { method: "GET", headers: { authorization: `Bearer ${token}` } });
  assert.equal(wrongMethod.statusCode, 405);

  // Missing messages.
  const noMessages = await invoke(handler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: {}
  });
  assert.equal(noMessages.statusCode, 400);
  assert.equal(noMessages.body.error, "missing_messages");

  // Invalid session token.
  const badToken = await invoke(handler, {
    method: "POST",
    headers: { authorization: "Bearer not-a-jwt" },
    body: { messages: [{ role: "user", content: "hi" }] }
  });
  assert.equal(badToken.statusCode, 401);
  assert.equal(badToken.body.error, "invalid_session");

  // Upstream 500 → proxy 502.
  const errorFetch = async () => new Response("upstream-broke", { status: 500 });
  const errorHandler = createAIChatHandler({ fetchImpl: errorFetch, aliyunApiKey: "x" });
  const upstreamError = await invoke(errorHandler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }] }
  });
  assert.equal(upstreamError.statusCode, 502);
  assert.equal(upstreamError.body.error, "upstream_error");
  assert.equal(upstreamError.body.status, 500);

  // Upstream unreachable → 502 upstream_unreachable.
  const throwFetch = async () => {
    throw new Error("econnrefused");
  };
  const throwHandler = createAIChatHandler({ fetchImpl: throwFetch, aliyunApiKey: "x" });
  const unreachable = await invoke(throwHandler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }] }
  });
  assert.equal(unreachable.statusCode, 502);
  assert.equal(unreachable.body.error, "upstream_unreachable");

  console.log("aiChatProxy tests passed");
} finally {
  if (originalSecret === undefined) delete process.env.SESSION_SECRET;
  else process.env.SESSION_SECRET = originalSecret;
  if (originalIssuer === undefined) delete process.env.SESSION_ISSUER;
  else process.env.SESSION_ISSUER = originalIssuer;
  if (originalKey === undefined) delete process.env.ALIYUN_API_KEY;
  else process.env.ALIYUN_API_KEY = originalKey;
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
    },
    write() {
      return true;
    },
    end() {
      return this;
    }
  };
}
