import { Pool } from "@neondatabase/serverless";

/**
 * Builds an `executeStatement` function backed by the Neon serverless `Pool`.
 *
 * `Pool` is the node-postgres compatible surface of `@neondatabase/serverless`,
 * which means callers can keep using `{ text, values }` parameterised SQL
 * with `$1, $2, ...` placeholders exactly like they would with `pg`.
 *
 * Returning the first row (or `null`) keeps the contract identical to the
 * previous `neon()` tagged-template implementation so that API handlers
 * (`api/form-analyses.js`) and the migration script (`backend/migrate.mjs`)
 * work without changes.
 *
 * The pool is reused across calls so we do not open a fresh TCP socket on
 * every invocation. The serverless driver will hand out / recycle
 * connections under the hood.
 *
 * @param {string} databaseUrl Neon Postgres connection string.
 * @param {{ createPool?: (databaseUrl: string) => any }} [deps] Test seam.
 * @returns {(statement: { text: string, values?: unknown[] }) => Promise<any>}
 */
export function createNeonExecutor(databaseUrl, deps = {}) {
  if (typeof databaseUrl !== "string" || databaseUrl.length === 0) {
    throw new Error("createNeonExecutor: databaseUrl must be a non-empty string");
  }
  const createPool = deps.createPool ?? defaultCreatePool;
  const pool = createPool(databaseUrl);

  return async function executeStatement(statement) {
    if (!statement || typeof statement.text !== "string") {
      throw new Error("executeStatement: statement.text must be a SQL string");
    }
    const values = Array.isArray(statement.values) ? statement.values : [];
    const result = await pool.query(statement.text, values);
    const rows = Array.isArray(result?.rows) ? result.rows : [];
    return rows[0] ?? null;
  };
}

function defaultCreatePool(databaseUrl) {
  return new Pool({ connectionString: databaseUrl });
}
