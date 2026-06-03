import { neon } from "@neondatabase/serverless";

/**
 * Builds an `executeStatement` function backed by the Neon serverless driver.
 *
 * The returned function accepts the same `{ text, values }` shape produced by
 * `formAnalysisRepository.buildInsertFormAnalysisSQL` so existing API handlers
 * do not need to change their call sites when this is wired in.
 *
 * @param {string} databaseUrl Neon Postgres connection string.
 * @returns {(statement: { text: string, values: unknown[] }) => Promise<any>}
 */
export function createNeonExecutor(databaseUrl) {
  if (typeof databaseUrl !== "string" || databaseUrl.length === 0) {
    throw new Error("createNeonExecutor: databaseUrl must be a non-empty string");
  }
  const sql = neon(databaseUrl);
  return async function executeStatement(statement) {
    if (!statement || typeof statement.text !== "string") {
      throw new Error("executeStatement: statement.text must be a SQL string");
    }
    const values = Array.isArray(statement.values) ? statement.values : [];
    // Neon returns the rows directly; .query(text, [values]) honours $1/$2 placeholders.
    const rows = await sql.query(statement.text, values);
    // Match the previous contract: return the first row or null.
    return rows[0] ?? null;
  };
}
