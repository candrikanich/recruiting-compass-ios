#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="${1:-TheRecruitingCompass}"
SCHEME="${2:-TheRecruitingCompass}"
DESTINATION="${3:-platform=iOS Simulator,name=iPhone 17}"

MAX_ATTEMPTS=2
LOG_FILE="$(mktemp -t ui-tests.XXXXXX.log)"

cleanup() {
  rm -f "$LOG_FILE"
}
trap cleanup EXIT

extract_simulator_name() {
  printf '%s' "$DESTINATION" | sed -n "s/.*name=\([^,']*\).*/\1/p"
}

simulator_preflight() {
  local sim_name
  sim_name="$(extract_simulator_name)"

  echo "UI test preflight: resetting simulator state..."
  xcrun simctl shutdown all >/dev/null 2>&1 || true

  if [[ -n "$sim_name" ]]; then
    xcrun simctl boot "$sim_name" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$sim_name" -b >/dev/null 2>&1 || true
  fi
}

run_ui_tests_once() {
  local attempt="$1"
  local status=0

  echo "Running UI tests (attempt ${attempt}/${MAX_ATTEMPTS})..."
  (
    cd "$PROJECT_DIR"
    xcodebuild test \
      -scheme "$SCHEME" \
      -destination "$DESTINATION" \
      -only-testing:TheRecruitingCompassUITests \
      -quiet
  ) 2>&1 | tee "$LOG_FILE" || status=${PIPESTATUS[0]}

  return "$status"
}

is_known_launch_error() {
  /usr/bin/grep -Eq "FBSOpenApplicationErrorDomain|Unknown application display identifier|xctrunner" "$LOG_FILE"
}

attempt=1
while (( attempt <= MAX_ATTEMPTS )); do
  simulator_preflight

  if run_ui_tests_once "$attempt"; then
    echo "UI tests passed."
    exit 0
  fi

  if (( attempt < MAX_ATTEMPTS )) && is_known_launch_error; then
    echo "Detected known simulator launch issue, retrying after reset..."
    ((attempt++))
    continue
  fi

  echo "UI tests failed."
  exit 1
done
