#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createNeonExecutor } from "./neonClient.mjs";

/**
 * Applies `backend/schema.sql` to a Neon Postgres instance.
 *
 * Usage:
 *   DATABASE_URL=postgres://... node backend/migrate.mjs
 *
 * The script is idempotent because every statement in `schema.sql` already
 * uses `if not exists`. Statements are split on a top-level `;` so that
 * `gen_random_uuid()` (loaded by the schema) is not treated as the end of
 * a statement when no other delimiter is present.
 */
async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error("DATABASE_URL is not set. Aborting migration.");
    process.exit(1);
  }

  const scriptPath = fileURLToPath(import.meta.url);
  const scriptDir = dirname(scriptPath);
  const schemaPath = join(scriptDir, "schema.sql");
  const schemaSql = await readFile(schemaPath, "utf8");

  const statements = splitSqlStatements(schemaSql);
  if (statements.length === 0) {
    console.log("No statements found in schema.sql; nothing to apply.");
    return;
  }

  const execute = createNeonExecutor(url);
  for (let i = 0; i < statements.length; i += 1) {
    const text = statements[i];
    const preview = text.replace(/\s+/g, " ").slice(0, 80);
    process.stdout.write(`[${i + 1}/${statements.length}] ${preview}... `);
    try {
      await execute({ text, values: [] });
      process.stdout.write("ok\n");
    } catch (error) {
      process.stdout.write("failed\n");
      console.error(error);
      process.exit(1);
    }
  }
  console.log(`Migration complete: ${statements.length} statements applied.`);
}

/**
 * Splits a multi-statement SQL script on `;` while ignoring empty fragments
 * and SQL comments. Good enough for `schema.sql` which only uses simple
 * `create table` / `create index` statements.
 */
export function splitSqlStatements(sql) {
  const stripped = sql
    .split("\n")
    .filter((line) => !line.trim().startsWith("--"))
    .join("\n");
  return stripped
    .split(";")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
