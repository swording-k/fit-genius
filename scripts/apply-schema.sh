#!/usr/bin/env bash
# Applies backend/schema.sql to the Neon Postgres instance configured via
# the DATABASE_URL environment variable.
#
# Usage:
#   DATABASE_URL=postgres://... ./scripts/apply-schema.sh
set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is not set. Aborting." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"
node backend/migrate.mjs
