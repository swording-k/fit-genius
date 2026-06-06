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
  FitGenius/Services/FormAnalysis/PoseFrameQualityPolicy.swift \
  FitGenius/Services/FormAnalysis/PoseFeedbackPlanner.swift \
  scripts/pose-feedback-planner-tests.swift \
  -o /tmp/pose-feedback-planner-tests
/tmp/pose-feedback-planner-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Services/FormAnalysis/PoseFrameQualityPolicy.swift \
  FitGenius/Services/FormAnalysis/PoseFeedbackPlanner.swift \
  scripts/pose-frame-quality-policy-tests.swift \
  -o /tmp/pose-frame-quality-policy-tests
/tmp/pose-frame-quality-policy-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Services/FormAnalysis/FormRuleEngine.swift \
  FitGenius/Services/FormAnalysis/FormCoachFeedbackBuilder.swift \
  scripts/form-coach-feedback-builder-tests.swift \
  -o /tmp/form-coach-feedback-builder-tests
/tmp/form-coach-feedback-builder-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Services/FormAnalysis/FormRuleEngine.swift \
  FitGenius/Services/FormAnalysis/FormExerciseClassifier.swift \
  scripts/form-coaching-quality-tests.swift \
  -o /tmp/form-coaching-quality-tests
/tmp/form-coaching-quality-tests

xcrun swiftc \
  FitGenius/Services/FormAnalysis/FormAnalysisPerformancePolicy.swift \
  scripts/form-analysis-performance-policy-tests.swift \
  -o /tmp/form-analysis-performance-policy-tests
/tmp/form-analysis-performance-policy-tests

xcrun swiftc \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Services/FormAnalysis/FormAnalysisQualityGate.swift \
  scripts/form-analysis-quality-gate-tests.swift \
  -o /tmp/form-analysis-quality-gate-tests
/tmp/form-analysis-quality-gate-tests

xcrun swiftc \
  FitGenius/Models/Diet/DietStatsModels.swift \
  scripts/diet-stats-calculator-tests.swift \
  -o /tmp/diet-stats-calculator-tests
/tmp/diet-stats-calculator-tests

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

xcrun swiftc \
  FitGenius/Services/FormAnalysis/SyncSettings.swift \
  scripts/sync-settings-notification-tests.swift \
  -o /tmp/sync-settings-notification-tests
/tmp/sync-settings-notification-tests

xcrun swiftc \
  FitGenius/Services/WatchPreparationState.swift \
  scripts/watch-preparation-state-tests.swift \
  -o /tmp/watch-preparation-state-tests
/tmp/watch-preparation-state-tests

xcrun swiftc \
  FitGeniusWidget/FitGeniusWidget.swift \
  FitGeniusWidget/WidgetPresentationModels.swift \
  scripts/widget-presentation-tests.swift \
  -o /tmp/widget-presentation-tests
/tmp/widget-presentation-tests

xcrun swiftc \
  FitGenius/Models/Diet/DietAnalysisFailurePolicy.swift \
  scripts/diet-analysis-failure-policy-tests.swift \
  -o /tmp/diet-analysis-failure-policy-tests
/tmp/diet-analysis-failure-policy-tests

scripts/product-localization-regression-tests.sh

xcrun swiftc \
  FitGenius/Services/AppLanguagePolicy.swift \
  scripts/app-language-policy-tests.swift \
  -o /tmp/app-language-policy-tests
/tmp/app-language-policy-tests

xcrun swiftc \
  FitGenius/Models/Plan/WorkoutCycleCalculator.swift \
  scripts/workout-cycle-calculator-tests.swift \
  -o /tmp/workout-cycle-calculator-tests
/tmp/workout-cycle-calculator-tests

xcrun swiftc \
  FitGenius/Models/Plan/WorkoutCompletionPolicy.swift \
  scripts/workout-completion-policy-tests.swift \
  -o /tmp/workout-completion-policy-tests
/tmp/workout-completion-policy-tests
