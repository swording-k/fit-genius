#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/fitgenius-ai-plan-tests.XXXXXX)
trap 'rm -r "$test_dir"' EXIT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
  FitGenius/Services/AIService.swift \
  FitGenius/Services/AIModelRouting.swift \
  FitGenius/Services/AppLanguagePolicy.swift \
  FitGenius/Services/ExerciseTemplateResolver.swift \
  FitGenius/Models/FitnessEnums.swift \
  FitGenius/Models/ProfileEnums.swift \
  FitGenius/Models/UserProfile.swift \
  FitGenius/Models/ChatMessage.swift \
  FitGenius/Models/Plan/WorkoutModels.swift \
  FitGenius/Models/Plan/WorkoutCycleCalculator.swift \
  FitGenius/Models/Plan/ExerciseTemplate.swift \
  FitGenius/Models/Diet/MealModels.swift \
  FitGenius/Models/Form/PoseModels.swift \
  FitGenius/Models/Form/FormCoachEnrichmentModels.swift \
  FitGenius/Services/FormAnalysis/FormCoachFeedbackBuilder.swift \
  FitGenius/Utilities/Extensions.swift \
  FitGenius/Utilities/LocalizedString.swift \
  FitGenius/Utilities/MuscleName.swift \
  FitGenius/Utilities/ExerciseNameZh.swift \
  scripts/ai-plan-generation-tests.swift \
  -o "$test_dir/tests"
if [[ $# -gt 0 ]]; then
  "$test_dir/tests" "$1"
else
  for test in missing-initial missing-regenerate invalid-initial invalid-regenerate empty-initial four-split regenerate-context direct; do
    "$test_dir/tests" "$test"
  done
fi
