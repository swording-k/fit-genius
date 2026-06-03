import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createNeonExecutor } from "../neonClient.mjs";

/**
 * Builds a fake `Pool` whose `query` records its inputs and returns whatever
 * the test queued in `nextResults`. Allows the test to assert what
 * `createNeonExecutor` actually calls without ever opening a TCP socket.
 */
function makeFakePoolFactory({ nextResults } = {}) {
  const queryCalls = [];
  const factory = (databaseUrl) => {
    return {
      databaseUrl,
      async query(text, values) {
        queryCalls.push({ text, values });
        const next = nextResults?.shift();
        if (next instanceof Error) throw next;
        return { rows: next ?? [] };
      },
    };
  };
  factory.queryCalls = queryCalls;
  return factory;
}

describe("createNeonExecutor", () => {
  it("rejects an empty databaseUrl", () => {
    assert.throws(
      () => createNeonExecutor(""),
      /databaseUrl must be a non-empty string/,
    );
  });

  it("passes $1/$2 placeholders + values array straight to the pool", async () => {
    const factory = makeFakePoolFactory({ nextResults: [[{ id: 1, name: "ada" }]] });
    const execute = createNeonExecutor("postgres://example/db", { createPool: factory });

    const row = await execute({
      text: "select id, name from users where id = $1",
      values: [1],
    });

    assert.deepEqual(row, { id: 1, name: "ada" });
    assert.equal(factory.queryCalls.length, 1);
    assert.equal(
      factory.queryCalls[0].text,
      "select id, name from users where id = $1",
    );
    assert.deepEqual(factory.queryCalls[0].values, [1]);
  });

  it("returns null when the pool returns zero rows", async () => {
    const factory = makeFakePoolFactory({ nextResults: [[]] });
    const execute = createNeonExecutor("postgres://example/db", { createPool: factory });

    const row = await execute({ text: "select 1", values: [] });

    assert.equal(row, null);
    assert.deepEqual(factory.queryCalls[0].values, []);
  });

  it("defaults a missing values array to []", async () => {
    const factory = makeFakePoolFactory({ nextResults: [[{ ok: true }]] });
    const execute = createNeonExecutor("postgres://example/db", { createPool: factory });

    const row = await execute({ text: "select ok from health" });

    assert.deepEqual(row, { ok: true });
    assert.deepEqual(factory.queryCalls[0].values, []);
  });

  it("propagates errors thrown by the pool", async () => {
    const factory = makeFakePoolFactory({ nextResults: [new Error("connection refused")] });
    const execute = createNeonExecutor("postgres://example/db", { createPool: factory });

    await assert.rejects(
      () => execute({ text: "select 1", values: [] }),
      /connection refused/,
    );
  });

  it("rejects a malformed statement", async () => {
    const factory = makeFakePoolFactory();
    const execute = createNeonExecutor("postgres://example/db", { createPool: factory });

    await assert.rejects(
      () => execute({ text: 42 }),
      /statement.text must be a SQL string/,
    );
    await assert.rejects(
      () => execute(null),
      /statement.text must be a SQL string/,
    );
  });

  it("hands the databaseUrl to the pool factory", () => {
    const factory = makeFakePoolFactory();
    createNeonExecutor("postgres://url:passed@host/db", { createPool: factory });
    // The factory closes over its calls; we exposed queryCalls but not the
    // constructed pool — assert the URL was forwarded by spying differently.
    let seenUrl = null;
    const spy = (url) => {
      seenUrl = url;
      return { async query() { return { rows: [] }; } };
    };
    createNeonExecutor("postgres://url:passed@host/db", { createPool: spy });
    assert.equal(seenUrl, "postgres://url:passed@host/db");
  });
});
