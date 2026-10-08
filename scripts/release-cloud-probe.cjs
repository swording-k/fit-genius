// Administrative release probe. Credentials/JWT stay in memory, never printed.
// Uses two random synthetic subjects; never targets an existing account.
const cp = require("node:child_process");
const { createHash, randomUUID } = require("node:crypto");
const path = require("node:path");
const CLI = "/Users/baojian/.workbuddy/binaries/node/cli-connector-packages/bin/tcb";
const ENV = "fitgenius-d0ghm1rz21cef6594";
const BASE = `https://${ENV}-1441969311.ap-shanghai.app.tcloudbase.com`;
function assert(value, message) { if (!value) throw Error(message); }
(async () => {
  let output;
  try {
    output = cp.execFileSync(CLI, ["api", "scf", "GetFunction", "--body", JSON.stringify({ FunctionName: "fitgenius-api", Namespace: ENV }), "--json"], { stdio: ["ignore", "pipe", "pipe"] }).toString();
  } catch { throw Error("Could not read administrative function configuration"); }
  const config = JSON.parse(output.slice(output.indexOf("{"))).data;
  const vars = Object.fromEntries(config.Environment.Variables.map(x => [x.Key, x.Value]));
  assert(vars.SESSION_SECRET?.length >= 32 && !!vars.MINIMAX_API_KEY, "Production secrets must remain configured");
  const { SignJWT } = await import(path.resolve("cloudfunctions/fitgenius-api/node_modules/jose/dist/node/esm/index.js"));
  const cleanupSubject = process.argv[2] === "--cleanup-subject" ? process.argv[3] : null;
  assert(!cleanupSubject || /^release-probe-[0-9a-f-]{36}$/.test(cleanupSubject), "Cleanup only accepts synthetic probe subjects");
  const subject = cleanupSubject || `release-probe-${randomUUID()}`;
  async function token(sub) {
    return new SignJWT({ sub, apple_sub: sub, generation: "0" }).setProtectedHeader({ alg: "HS256" })
      .setIssuer(vars.SESSION_ISSUER || "fitgenius").setIssuedAt().setExpirationTime("10m")
      .sign(new TextEncoder().encode(vars.SESSION_SECRET));
  }
  const bearer = await token(subject), other = await token(`release-probe-${randomUUID()}`);
  async function request(route, method, body, auth = bearer, expected = 200) {
    const response = await fetch(BASE + route, { method, headers: {
      "Content-Type": "application/json", ...(auth ? { Authorization: `Bearer ${auth}` } : {})
    }, ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(65000) });
    const data = await response.json();
    assert(response.status === expected, `${method} ${route.split("?")[0]}: HTTP${response.status}/${data.error || "unexpected"} ${data.diagnostic ? JSON.stringify(data.diagnostic) : ""}`);
    return data;
  }
  if (cleanupSubject) {
    await request("/api/account", "DELETE");
    console.log("synthetic probe cleanup: PASS " + cleanupSubject);
    return;
  }
  await request("/api/health", "GET", null, null);
  for (const route of ["/api/account", "/api/cloud-snapshot"]) {
    const method = route.endsWith("account") ? "DELETE" : "GET";
    await request(route, method, null, null, 401);
    await request(route, method, null, "invalid", 401);
  }
  console.log("health/auth boundaries: PASS");
  let cleanupNeeded = false;
  try {
    const small = { schemaVersion: 2, profile: null, workoutPlan: null, mealDays: [] };
    await request("/api/cloud-snapshot", "PUT", small); cleanupNeeded = true;
    const large = { ...small, workoutPlan: { creationDate: "2026-10-08T00:00:00Z", name: "训练💪".repeat(18000), days: [] } };
    const bytes = Buffer.from(JSON.stringify(large)), size = 48 * 1024;
    const id = randomUUID(), count = Math.ceil(bytes.length / size);
    for (let index = 0; index < count; index++) {
      const chunk = bytes.subarray(index * size, (index + 1) * size).toString("base64");
      const payload = { snapshotUpload: { id, index, count, chunk } };
      assert(Buffer.byteLength(JSON.stringify(payload)) < 100000, "Gateway request budget");
      const ack = await request("/api/cloud-snapshot", "PUT", payload);
      assert(ack.snapshotUpload?.complete === (index === count - 1), "Atomic completion ack");
      if (index === 0) {
        const old = await request("/api/cloud-snapshot", "GET");
        assert(old.snapshot?.workoutPlan === null, "Partial upload changed old snapshot");
      }
    }
    const descriptor = await request("/api/cloud-snapshot", "GET");
    assert(descriptor.snapshotDownload?.id === id && descriptor.snapshotDownload.count === count, "Large descriptor");
    const parts = [];
    for (let index = 0; index < count; index++) {
      const reply = await request(`/api/cloud-snapshot?download=${id}&chunk=${index}`, "GET");
      assert(reply.snapshotChunk?.index === index && reply.snapshotChunk.id === id, "Query/identity transmission");
      parts.push(Buffer.from(reply.snapshotChunk.chunk, "base64"));
    }
    const returned = Buffer.concat(parts);
    assert(returned.equals(bytes) && createHash("sha256").update(returned).digest("hex") === descriptor.snapshotDownload.sha256, "Large UTF8 byte roundtrip");
    await request("/api/cloud-snapshot", "GET", null, other, 404);
    await request(`/api/cloud-snapshot?download=${id}&chunk=0`, "GET", null, other, 404);
    console.log(`large snapshot ${bytes.length} bytes/${count} chunks, partial preservation and isolation: PASS`);
    await request("/api/account", "DELETE");
    await request("/api/account", "DELETE");
    cleanupNeeded = false;
    await request("/api/cloud-snapshot", "GET", null, bearer, 401);
    await request("/api/cloud-snapshot", "PUT", small, bearer, 401);
    console.log("isolated account delete, idempotence and old-session revocation: PASS");
    console.log("release-cloud-probe: PASS; production provider/session variables preserved");
  } finally {
    if (cleanupNeeded) {
      try { await request("/api/account", "DELETE"); console.log("synthetic probe cleanup: PASS"); }
      catch { console.error("Synthetic probe cleanup requires retry; subject=" + subject + "; no real account was targeted"); }
    }
  }
})().catch(error => { console.error(String(error.message).slice(0, 240)); process.exitCode = 1; });
