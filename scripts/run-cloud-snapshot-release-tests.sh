#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/fitgenius-cloud-tests.XXXXXX)
trap 'rm -r "$test_dir"' EXIT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
 FitGenius/Models/FitnessEnums.swift FitGenius/Models/ProfileEnums.swift \
 FitGenius/Models/UserProfile.swift FitGenius/Models/Plan/WorkoutModels.swift \
 FitGenius/Models/Plan/WorkoutCycleCalculator.swift FitGenius/Models/Plan/ExerciseTemplate.swift \
 FitGenius/Models/Diet/MealModels.swift FitGenius/Models/Health/HealthInsightModels.swift \
 FitGenius/Models/CloudSnapshotModels.swift FitGenius/Utilities/Extensions.swift \
 FitGenius/Utilities/LocalizedString.swift FitGenius/Utilities/ExerciseNameZh.swift \
 FitGenius/Utilities/MuscleName.swift FitGenius/Services/CurrentWorkoutPlanPolicy.swift \
 FitGenius/Services/CurrentWorkoutPlanStore.swift FitGenius/Services/FormAnalysis/SyncSettings.swift \
 FitGenius/Services/CloudSnapshotWireClient.swift FitGenius/Services/CloudSnapshotService.swift FitGenius/Services/CloudSnapshotCoordinator.swift \
 scripts/cloud-snapshot-coordinator-release-tests.swift -o "$test_dir/tests"
"$test_dir/tests"
