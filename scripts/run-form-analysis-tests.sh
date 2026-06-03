#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

swiftc -D DEBUG \
  FitGenius/Services/FormAnalysis/DebugFormAnalysisVideoProvider.swift \
  scripts/debug-video-provider-tests.swift \
  -o /tmp/debug-video-provider-tests
/tmp/debug-video-provider-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Models/Form/FormAnalysisModels.swift \
  FitGenius/Models/Form/FormAnalysisSyncPayload.swift \
  scripts/form-analysis-sync-payload-tests.swift \
  -o /tmp/form-analysis-sync-payload-tests
/tmp/form-analysis-sync-payload-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Models/Form/FormAnalysisModels.swift \
  FitGenius/Models/Form/FormAnalysisSyncPayload.swift \
  FitGenius/Services/FormAnalysis/FormAnalysisSyncService.swift \
  scripts/form-analysis-sync-service-tests.swift \
  -o /tmp/form-analysis-sync-service-tests
/tmp/form-analysis-sync-service-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Models/Form/FormAnalysisModels.swift \
  FitGenius/Models/Form/FormAnalysisSyncPayload.swift \
  FitGenius/Services/FormAnalysis/FormAnalysisSyncService.swift \
  FitGenius/Services/FormAnalysis/SyncSettings.swift \
  FitGenius/Services/FormAnalysis/FormAnalysisSyncCoordinator.swift \
  scripts/form-analysis-sync-coordinator-tests.swift \
  -o /tmp/form-analysis-sync-coordinator-tests
/tmp/form-analysis-sync-coordinator-tests

xcrun swiftc \
  FitGenius/Services/FormAnalysis/SyncSettings.swift \
  FitGenius/Services/AppleAuthAPIClient.swift \
  scripts/apple-auth-api-client-tests.swift \
  -o /tmp/apple-auth-api-client-tests
/tmp/apple-auth-api-client-tests
