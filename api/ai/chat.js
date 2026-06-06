import { extractBearerToken, verifySessionToken } from "../../backend/sessionToken.mjs";

const ALIYUN_ENDPOINT = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
const DEFAULT_MODEL = "qwen3-omni-flash";

export const config = {
  maxDuration: 60
};

/**
 * Creates a Vercel-style handler that proxies chat completions to the
 * Aliyun OpenAI-compatible API using a server-side ALIYUN_API_KEY.
 *
 * The handler enforces a valid FitGenius session token before forwarding
 * the request; provider API keys never reach the iOS bundle.
 *
 * @param {object} [deps]
 * @param {typeof fetch} [deps.fetchImpl] Override for tests.
 * @param {string} [deps.aliyunApiKey] Override for tests; defaults to env.
 */
export function createAIChatHandler({ fetchImpl, aliyunApiKey } = {}) {
  const fetchFn = fetchImpl || globalThis.fetch;
  return async function handler(request, response) {
    if (request.method !== "POST") {
      response.setHeader("Allow", "POST");
      response.status(405).json({ ok: false, error: "method_not_allowed" });
      return;
    }

    const bearer = extractBearerToken(request.headers?.authorization);
    if (!bearer) {
      response.status(401).json({ ok: false, error: "missing_authorization" });
      return;
    }
    try {
      await verifySessionToken(bearer);
    } catch (error) {
      response.status(401).json({ ok: false, error: "invalid_session" });
      return;
    }

    const apiKey = aliyunApiKey ?? process.env.ALIYUN_API_KEY;
    if (!apiKey) {
      response.status(503).json({ ok: false, error: "provider_not_configured" });
      return;
    }

    const { messages, model, stream } = request.body ?? {};
    if (!Array.isArray(messages) || messages.length === 0) {
      response.status(400).json({ ok: false, error: "missing_messages" });
      return;
    }

    const upstreamBody = {
      model: model || DEFAULT_MODEL,
      messages,
      stream: Boolean(stream)
    };

    let upstreamResponse;
    try {
      upstreamResponse = await fetchFn(ALIYUN_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`
        },
        body: JSON.stringify(upstreamBody)
      });
    } catch (error) {
      response.status(502).json({ ok: false, error: "upstream_unreachable" });
      return;
    }

    if (!upstreamResponse.ok) {
      const errorText = await safeText(upstreamResponse);
      response.status(502).json({
        ok: false,
        error: "upstream_error",
        status: upstreamResponse.status,
        detail: errorText.slice(0, 2000)
      });
      return;
    }

    if (upstreamBody.stream && upstreamResponse.body) {
      // Stream SSE chunks back to the client unchanged.
      response.setHeader("Content-Type", "text/event-stream");
      response.setHeader("Cache-Control", "no-cache");
      response.setHeader("Connection", "keep-alive");
      const reader = upstreamResponse.body.getReader();
      response.status(200);
      try {
        // Vercel/Node support piping a Web ReadableStream to the response.
        await pipeStream(reader, response);
      } catch (error) {
        // Best-effort close; client will see the truncation on its side.
      }
      return;
    }

    const data = await safeJson(upstreamResponse);
    response.status(200).json({ ok: true, data });
  };
}

async function safeText(response) {
  try {
    return await response.text();
  } catch {
    return "";
  }
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

async function pipeStream(reader, response) {
  // Vercel's req/res objects are not standard Web Streams. We just push
  // decoded chunks through the response object directly.
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    if (value && typeof response.write === "function") {
      response.write(Buffer.from(value));
    }
  }
  if (typeof response.end === "function") {
    response.end();
  }
}

export default createAIChatHandler();
