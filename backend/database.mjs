import { createNeonExecutor } from "./neonClient.mjs";

/**
 * Returns an `executeStatement` function backed by Neon when `DATABASE_URL`
 * is configured, or `null` when it is missing.
 *
 * API handlers should treat `null` as the "validated-only" mode that was
 * already covered by the original test suite.
 *
 * @returns {((statement: { text: string, values: unknown[] }) => Promise<any>) | null}
 */
export function createExecutor() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    return null;
  }
  return createNeonExecutor(url);
}

// Re-export so consumers can wire the executor directly.
export { createNeonExecutor };
