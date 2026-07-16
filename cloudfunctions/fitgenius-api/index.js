"use strict";

const cloudbase = require("@cloudbase/node-sdk");
const { extractBearerToken, verifySessionToken, signSessionToken } = require("./backend/sessionToken.cjs");
const { resolveAIProviderConfig, resolveUpstreamModel } = require("./backend/aiProviderConfig.cjs");
const { verifyAppleIdentityToken } = require("./backend/appleTokenVerifier.cjs");

// ── CloudBase NoSQL (server-side) ─────────────────────────
// The function runs inside the `fitgenius` BaaS env, so node-sdk picks up the
// env's service identity automatically — no secretId/secretKey needed.
const ENV_ID = process.env.TCB_ENV || "fitgenius-d0ghm1rz21cef6594";
const app = cloudbase.init({ env: ENV_ID });
const db = app.database();

// ── Auth helper ───────────────────────────────────────────
function authError(status, error) {
  const e = new Error(error);
  e.httpStatus = status;
  e.errorCode = error;
  return e;
}

async function authenticate(event) {
  const authHeader = event.headers?.authorization || event.headers?.Authorization || "";
  const bearer = extractBearerToken(authHeader);
  if (!bearer) throw authError(401, "missing_authorization");
  try {
    return await verifySessionToken(bearer);
  } catch {
    throw authError(401, "invalid_session");
  }
}

exports.main = async (event, context) => {
  const method = (event.httpMethod || "GET").toUpperCase();
  let path = (event.path || "/").replace(/\/+$/, "") || "/";

  // CloudBase HTTP gateway note: routes provisioned via the gateway `createRoute`
  // action default to EnablePathTransmission = false, which strips the request
  // path before it reaches this Event function (event.path arrives as "/"). The
  // built-in routes (health / auth/apple / ai/chat) were provisioned with path
  // transmission ON and keep their real paths. The two cloud-sync routes
  // (/api/form-analyses, /api/cloud-snapshot) are served through transmission-off
  // routes to avoid depending on a console-only flag; we recover the intended
  // route from the HTTP method, which is unique per sync endpoint:
  //   POST -> /api/form-analyses        (form-analysis sync, write-only)
  //   GET  -> /api/cloud-snapshot       (snapshot download)
  //   PUT  -> /api/cloud-snapshot       (snapshot upload)
  // A path of "/" can ONLY originate from these transmission-off sync routes, so
  // this mapping is unambiguous (the transmission-ON routes always carry their
  // real, non-root path).
  if (path === "/" && (method === "POST" || method === "GET" || method === "PUT")) {
    path = method === "POST" ? "/api/form-analyses" : "/api/cloud-snapshot";
  }

  // ── Health ──────────────────────────────────────────────
  if (path === "/api/health") {
    return json(200, { ok: true, status: "healthy", ts: Date.now() });
  }

  // ── Apple Auth ──────────────────────────────────────────
  if (path === "/api/auth/apple") {
    if (method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });

    const body = safeParse(event.body);
    const { identityToken, email, fullName } = body ?? {};

    if (!identityToken) return json(400, { ok: false, error: "missing_identity_token" });

    try {
      const claims = await verifyAppleIdentityToken(identityToken);
      const session = await signSessionToken({
        sub: claims.sub,
        email: claims.email || email || "",
        name: fullName || {}
      });
      // Response must match AppleAuthSession struct in iOS app:
      // { ok, mode?, sessionToken, userId, expiresAt?, displayName? }
      return json(200, {
        ok: true,
        mode: "validated_only",
        sessionToken: session.token,
        userId: claims.sub,
        expiresAt: session.expiresAt,
        displayName: fullName?.givenName || null
      });
    } catch (err) {
      return json(401, { ok: false, error: "invalid_identity_token", detail: err.message || String(err) });
    }
  }

  // ── AI Chat ─────────────────────────────────────────────
  if (path === "/api/ai/chat") {
    if (method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });

    // verify session
    const authHeader = event.headers?.authorization || event.headers?.Authorization || "";
    const bearer = extractBearerToken(authHeader);
    if (!bearer) return json(401, { ok: false, error: "missing_authorization" });
    try {
      await verifySessionToken(bearer);
    } catch {
      return json(401, { ok: false, error: "invalid_session" });
    }

    // resolve provider
    let provider;
    try {
      provider = resolveAIProviderConfig(process.env);
    } catch {
      return json(503, { ok: false, error: "provider_not_configured" });
    }
    if (!provider.apiKey) return json(503, { ok: false, error: "provider_not_configured" });

    // parse body
    const body = safeParse(event.body);
    const { messages, model } = body ?? {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return json(400, { ok: false, error: "missing_messages" });
    }

    const upstreamBody = {
      model: resolveUpstreamModel(model, provider),
      messages,
      stream: false,  // Cloud Functions don't support SSE; use non-streaming
      // Disable MiniMax-M3 thinking mode. We need fast, structured JSON for
      // plan-modification commands. Thinking mode emits <think>…</think> tags and,
      // on vague "整体加强"-style requests, can spin in reasoning past the 50s SCF
      // timeout without ever emitting the JSON the iOS client needs.
      // (reasoning_split only controls HOW thinking is returned; it cannot turn
      // thinking off — `thinking: {type:"disabled"}` is what actually disables it.)
      thinking: { type: "disabled" }
    };

    try {
      const nonStreamBody = { ...upstreamBody, stream: false };
      const result = await httpRequest(provider.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${provider.apiKey}`
        },
        body: JSON.stringify(nonStreamBody),
        timeout: 50000
      });

      if (result.statusCode < 200 || result.statusCode >= 300) {
        return json(502, { ok: false, error: "upstream_error", status: result.statusCode, detail: result.body.slice(0, 2000) });
      }

      let data;
      try { data = JSON.parse(result.body); } catch { data = null; }
      if (!data || !Array.isArray(data.choices) || data.choices.length === 0) {
        return json(502, { ok: false, error: "bad_upstream_response", detail: result.body.slice(0, 2000) });
      }

      // Normalize the returned message so the iOS client always gets something parseable:
      // 1) If `content` is empty (can happen with reasoning models), fall back to `reasoning_content`.
      // 2) Strip ```json / ``` markdown fences (the client also does this, but doing it here
      //    makes the contract robust even if the client ever changes).
      const rawMessage = data.choices[0].message || {};
      const safeContent = pickContent(rawMessage);
      return json(200, {
        ok: true,
        data: {
          choices: [{
            message: {
              content: safeContent,
              reasoning_content: rawMessage.reasoning_content || ""
            }
          }]
        }
      });
    } catch (err) {
      return json(502, { ok: false, error: "upstream_unreachable", detail: err.message || String(err) });
    }
  }

  // ── Form Analyses Sync (POST) ───────────────────────────
  // iOS calls FormAnalysisSyncService.sync → POST /api/form-analyses with
  // `Authorization: Bearer <session>` + `X-FitGenius-User-Id` and a JSON payload.
  // Success contract: HTTP 2xx AND body.ok === true.
  if (path === "/api/form-analyses") {
    if (method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });

    let claims;
    try { claims = await authenticate(event); }
    catch (e) { return json(e.httpStatus || 401, { ok: false, error: e.errorCode }); }

    const body = safeParse(event.body);
    if (!body || typeof body !== "object") {
      return json(400, { ok: false, error: "invalid_body" });
    }

    try {
      const res = await db.collection("form_analyses").add({
        userId: claims.userId,
        createdAt: new Date().toISOString(),
        payload: body
      });
      const localIdentifier = (res && (res.id || res._id)) ? String(res.id || res._id) : "";
      return json(200, { ok: true, localIdentifier, mode: "stored" });
    } catch (err) {
      return json(500, { ok: false, error: "db_write_failed", detail: err.message || String(err) });
    }
  }

  // ── Cloud Snapshot Sync (GET / PUT) ─────────────────────
  // iOS CloudSnapshotService:
  //   GET  → expects 200 + { snapshot, updatedAt }; 404 == no remote snapshot.
  //   PUT  → sends the full CloudSnapshot JSON; expects 200 + { snapshot, updatedAt }.
  // NOTE: PUT carries the full account snapshot. Per-user snapshots that exceed
  // the CloudBase JSON body ~100KB gateway limit will be rejected upstream
  // (EXCEED_MAX_PAYLOAD_SIZE) before reaching this function. Large-account
  // support requires an iOS change (upload to Storage, send URL pointer) — see
  // README "云同步" section. Small/new accounts sync fine as-is.
  if (path === "/api/cloud-snapshot") {
    let claims;
    try { claims = await authenticate(event); }
    catch (e) { return json(e.httpStatus || 401, { ok: false, error: e.errorCode }); }

    if (method === "GET") {
      try {
        const res = await db.collection("cloud_snapshots").where({ userId: claims.userId }).limit(1).get();
        const docs = (res && res.data) || [];
        if (docs.length === 0) return json(404, { ok: false, error: "not_found" });
        const doc = docs[0];
        return json(200, { ok: true, snapshot: doc.snapshot, updatedAt: doc.updatedAt });
      } catch (err) {
        return json(500, { ok: false, error: "db_read_failed", detail: err.message || String(err) });
      }
    }

    if (method === "PUT") {
      const body = safeParse(event.body);
      if (!body || typeof body !== "object") {
        return json(400, { ok: false, error: "invalid_body" });
      }
      const updatedAt = new Date().toISOString();
      try {
        const res = await db.collection("cloud_snapshots").where({ userId: claims.userId }).limit(1).get();
        const docs = (res && res.data) || [];
        if (docs.length > 0) {
          await db.collection("cloud_snapshots").doc(docs[0]._id).update({ snapshot: body, updatedAt });
        } else {
          await db.collection("cloud_snapshots").add({
            userId: claims.userId,
            snapshot: body,
            updatedAt
          });
        }
        return json(200, { ok: true, snapshot: body, updatedAt });
      } catch (err) {
        return json(500, { ok: false, error: "db_write_failed", detail: err.message || String(err) });
      }
    }

    return json(405, { ok: false, error: "method_not_allowed" });
  }

  // ── 404 ─────────────────────────────────────────────────
  return json(404, { ok: false, error: "not_found" });
};

// helpers
function pickContent(message) {
  if (!message || typeof message !== "object") return "";
  const raw = String(message.content || "").trim();
  if (raw.length > 0) return stripMarkdownFence(raw);
  // Empty `content`: reasoning models sometimes put the answer in reasoning_content.
  const reasoning = String(message.reasoning_content || "").trim();
  return stripMarkdownFence(reasoning);
}

// Remove a leading/trailing ```json or ``` markdown fence, if present.
function stripMarkdownFence(text) {
  let t = text.trim();
  if (t.startsWith("```json")) t = t.slice(7);
  else if (t.startsWith("```")) t = t.slice(3);
  if (t.endsWith("```")) t = t.slice(0, -3);
  return t.trim();
}

function json(code, body) {
  return {
    statusCode: code,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  };
}

function safeParse(raw) {
  if (!raw) return null;
  if (typeof raw === "object") return raw;
  try { return JSON.parse(raw); } catch { return null; }
}

function httpRequest(url, options) {
  return new Promise((resolve, reject) => {
    const { hostname, pathname, port, protocol } = new URL(url);
    const isHttps = protocol === "https:";
    const mod = isHttps ? require("https") : require("http");

    const req = mod.request({
      hostname,
      port: port || (isHttps ? 443 : 80),
      path: pathname + (new URL(url).search || ""),
      method: options.method || "GET",
      headers: options.headers || {},
      timeout: options.timeout || 30000
    }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString("utf-8")
        });
      });
    });

    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("Request timeout"));
    });

    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}
