#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/fitgenius-tutorial-tests.XXXXXX)
trap 'rm -r "$test_dir"' EXIT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
 FitGenius/Models/Plan/ExerciseTutorialClip.swift \
 FitGenius/Services/ExerciseTutorialCatalog.swift \
 scripts/tutorial-discovery-tests.swift -o "$test_dir/discovery"
"$test_dir/discovery"
