import assert from "node:assert/strict";
import test from "node:test";
import { createAccountHandler } from "../../api/account.js";

test("account delete removes the authenticated user", async () => {
  let statement;
  const handler = createAccountHandler({
    verifyToken: async () => ({ userId: "user-1" }),
    executeStatement: async (value) => {
      statement = value;
      return { id: "user-1" };
    }
  });
  const response = await invoke(handler, {
    method: "DELETE",
    headers: { authorization: "Bearer valid" }
  });
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.deleted, true);
  assert.deepEqual(statement.values, ["user-1"]);
});

test("account delete rejects missing authorization", async () => {
  const handler = createAccountHandler({ executeStatement: async () => null });
  const response = await invoke(handler, { method: "DELETE", headers: {} });
  assert.equal(response.statusCode, 401);
});

test("account delete rejects unsupported methods", async () => {
  const handler = createAccountHandler({ executeStatement: async () => null });
  const response = await invoke(handler, { method: "GET", headers: {} });
  assert.equal(response.statusCode, 405);
});

async function invoke(handler, request) {
  const result = {
    statusCode: 200,
    headers: {},
    body: null,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; }
  };
  await handler(request, result);
  return result;
}
