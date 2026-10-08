#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
node scripts/account-deletion-regression-tests.mjs
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
  FitGenius/Models/FitnessEnums.swift FitGenius/Models/ProfileEnums.swift \
  FitGenius/Utilities/LocalizedString.swift FitGenius/Utilities/ExerciseNameZh.swift \
  FitGenius/Utilities/MuscleName.swift FitGenius/Utilities/Extensions.swift \
  FitGenius/Models/UserProfile.swift FitGenius/Models/Plan/WorkoutModels.swift \
  FitGenius/Models/Plan/WorkoutCycleCalculator.swift FitGenius/Models/Plan/ExerciseTemplate.swift \
  FitGenius/Models/Diet/MealModels.swift FitGenius/Models/ChatMessage.swift \
  FitGenius/Models/Form/PoseModels.swift FitGenius/Models/Form/FormAnalysisModels.swift \
  FitGenius/Models/Health/HealthInsightModels.swift FitGenius/Services/FormAnalysis/SyncSettings.swift \
  FitGenius/Services/AccountDeletionService.swift FitGenius/Services/LocalAccountDataCleaner.swift \
  scripts/local-account-data-cleaner-tests.swift -o /tmp/fitgenius-account-cleaner-tests
/tmp/fitgenius-account-cleaner-tests
