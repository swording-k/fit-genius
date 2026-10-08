#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node --test cloudfunctions/fitgenius-api/tests/release-data.test.cjs
bash scripts/run-ai-plan-generation-tests.sh
bash scripts/run-cloud-snapshot-release-tests.sh
zsh scripts/run-account-deletion-tests.sh
test_dir=$(mktemp -d /tmp/fitgenius-release-tests.XXXXXX)
trap 'rm -r "$test_dir"' EXIT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
 FitGenius/Services/CloudSnapshotWireClient.swift scripts/cloud-snapshot-wire-tests.swift -o "$test_dir/wire"
"$test_dir/wire"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
 FitGenius/Services/FormAnalysis/SyncSettings.swift scripts/backend-gateway-migration-tests.swift -o "$test_dir/gateway"
"$test_dir/gateway"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
 FitGenius/Models/Form/PoseModels.swift FitGenius/Models/Form/FormAnalysisModels.swift \
 FitGenius/Models/Form/FormAnalysisSyncPayload.swift \
 FitGenius/Services/FormAnalysis/FormAnalysisSyncService.swift \
 FitGenius/Services/FormAnalysis/FormAnalysisSyncCoordinator.swift \
 FitGenius/Services/FormAnalysis/SyncSettings.swift \
 scripts/form-analysis-sync-coordinator-tests.swift -o "$test_dir/form-sync"
"$test_dir/form-sync"
scripts/check-localization.sh
git diff --check
