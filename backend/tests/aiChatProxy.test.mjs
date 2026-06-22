import assert from "node:assert/strict";
import { signSessionToken } from "../sessionToken.mjs";
import { createAIChatHandler } from "../../api/ai/chat.js";

const originalSecret = process.env.SESSION_SECRET;
const originalIssuer = process.env.SESSION_ISSUER;

try {
  process.env.SESSION_SECRET = "z".repeat(32);
  delete process.env.SESSION_ISSUER;

  const minimaxEnv = {
    AI_PROVIDER: "minimax",
    MINIMAX_API_KEY: "test-minimax-key"
  };

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
  const handler = createAIChatHandler({ fetchImpl: fakeFetch, providerEnv: minimaxEnv });

  // Happy path.
  const ok = await invoke(handler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }], model: "qwen3-omni-flash" }
  });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.body.ok, true);
  assert.equal(captured.url, "https://api.minimaxi.com/v1/chat/completions");
  assert.match(captured.init.headers.Authorization, /^Bearer test-minimax-key/);
  const sentBody = JSON.parse(captured.init.body);
  assert.equal(sentBody.model, "MiniMax-M3");
  assert.equal(sentBody.messages[0].role, "user");
  assert.equal(sentBody.stream, false);
  assert.equal(sentBody.reasoning_split, true);

  // Multimodal message content must be forwarded without flattening or
  // rewriting the image payload.
  const multimodalMessages = [{
    role: "user",
    content: [
      { type: "text", text: "describe" },
      { type: "image_url", image_url: { url: "data:image/jpeg;base64,/9j/" } }
    ]
  }];
  const multimodal = await invoke(handler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: multimodalMessages, model: "qwen-vl-max" }
  });
  assert.equal(multimodal.statusCode, 200);
  const multimodalBody = JSON.parse(captured.init.body);
  assert.deepEqual(multimodalBody.messages, multimodalMessages);
  assert.equal(multimodalBody.model, "MiniMax-M3");
  assert.equal(multimodalBody.reasoning_split, true);

  // MiniMax streaming SSE is forwarded unchanged. MiniMax may close the
  // stream without a final [DONE] marker, which the current iOS client accepts.
  const streamFetch = async () => new Response(
    "data: {\"choices\":[{\"delta\":{\"content\":\"hello\"}}]}\n\n",
    { status: 200, headers: { "Content-Type": "text/event-stream" } }
  );
  const streamHandler = createAIChatHandler({ fetchImpl: streamFetch, providerEnv: minimaxEnv });
  const streamed = await invoke(streamHandler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }], stream: true }
  });
  assert.equal(streamed.statusCode, 200);
  assert.equal(streamed.headers["Content-Type"], "text/event-stream");
  assert.match(streamed.streamBody, /\"content\":\"hello\"/);

  // Environment-only rollback keeps the old provider available without a
  // mobile release.
  const aliyunHandler = createAIChatHandler({
    fetchImpl: fakeFetch,
    providerEnv: { AI_PROVIDER: "aliyun", ALIYUN_API_KEY: "test-aliyun-key" }
  });
  const rollback = await invoke(aliyunHandler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }], model: "fitgenius-vision" }
  });
  assert.equal(rollback.statusCode, 200);
  assert.match(captured.url, /dashscope\.aliyuncs\.com/);
  const rollbackBody = JSON.parse(captured.init.body);
  assert.equal(rollbackBody.model, "qwen-vl-max");
  assert.equal("reasoning_split" in rollbackBody, false);

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
  const errorHandler = createAIChatHandler({ fetchImpl: errorFetch, providerEnv: minimaxEnv });
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
  const throwHandler = createAIChatHandler({ fetchImpl: throwFetch, providerEnv: minimaxEnv });
  const unreachable = await invoke(throwHandler, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }] }
  });
  assert.equal(unreachable.statusCode, 502);
  assert.equal(unreachable.body.error, "upstream_unreachable");

  const missingProvider = createAIChatHandler({
    fetchImpl: fakeFetch,
    providerEnv: { AI_PROVIDER: "minimax" }
  });
  const notConfigured = await invoke(missingProvider, {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: { messages: [{ role: "user", content: "hi" }] }
  });
  assert.equal(notConfigured.statusCode, 503);
  assert.equal(notConfigured.body.error, "provider_not_configured");

  console.log("aiChatProxy tests passed");
} finally {
  if (originalSecret === undefined) delete process.env.SESSION_SECRET;
  else process.env.SESSION_SECRET = originalSecret;
  if (originalIssuer === undefined) delete process.env.SESSION_ISSUER;
  else process.env.SESSION_ISSUER = originalIssuer;
}

async function invoke(targetHandler, request) {
  const response = createResponse();
  await targetHandler(request, response);
  return response.result;
}

function createResponse() {
  const result = { statusCode: 200, headers: {}, body: undefined, streamBody: "" };
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
    write(chunk) {
      result.streamBody += Buffer.isBuffer(chunk) ? chunk.toString("utf8") : String(chunk);
      return true;
    },
    end() {
      return this;
    }
  };
}
