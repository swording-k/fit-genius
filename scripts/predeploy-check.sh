#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

require_env=false
if [[ "${1:-}" == "--require-env" ]]; then
  require_env=true
fi

echo "== Backend tests =="
npm run test:backend

echo "\n== iOS form-analysis tests =="
scripts/run-form-analysis-tests.sh

echo "\n== Localization =="
scripts/check-localization.sh

echo "\n== Secret scan =="
if rg "sk-(api-)?[A-Za-z0-9]{12,}|(ALIYUN|MINIMAX)_API_KEY =[^[:space:]]|<key>(ALIYUN|MINIMAX)" -n . \
  -g '!*.xcuserstate' \
  -g '!*.png' \
  -g '!node_modules/**' \
  -g '!docs/**' \
  -g '!scripts/predeploy-check.sh'; then
  echo "Potential secret-like value found. Review before deploying."
  exit 1
else
  echo "No secret-like values found in deployable files."
fi

echo "\n== Required deployment environment variables =="
required_vars=(
  DATABASE_URL
  SESSION_SECRET
  APPLE_BUNDLE_ID
)

provider="${AI_PROVIDER:-minimax}"
case "$provider" in
  minimax) required_vars+=(MINIMAX_API_KEY) ;;
  aliyun) required_vars+=(ALIYUN_API_KEY) ;;
  *)
    echo "Unsupported AI_PROVIDER: $provider"
    exit 1
    ;;
esac

missing=()
for name in "${required_vars[@]}"; do
  if [[ -z "${(P)name:-}" ]]; then
    missing+=("$name")
    echo "missing: $name"
  else
    echo "present: $name"
  fi
done

if (( ${#missing[@]} > 0 )); then
  if [[ "$require_env" == true ]]; then
    echo "Missing required environment variables: ${missing[*]}"
    exit 1
  fi
  echo "Environment variables are not required for local checks. Use --require-env before a real deploy."
fi

echo "\nPredeploy checks passed."
