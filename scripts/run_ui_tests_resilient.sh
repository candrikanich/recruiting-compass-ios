#!/usr/bin/env bash
# Avoid running another xcodebuild for this scheme while this script runs —
# concurrent builds share DerivedData and can wedge with "build.db is locked".

set -euo pipefail

PROJECT_DIR="${1:-TheRecruitingCompass}"
SCHEME="${2:-TheRecruitingCompass}"
DESTINATION="${3:-platform=iOS Simulator,name=iPhone 17}"

MAX_ATTEMPTS=3
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

  echo "UI test preflight: preparing destination simulator..."
  # Avoid `simctl shutdown all` — it strands the UI test runner while Xcode/Launch
  # Services poll every ~30s (IDELaunchParametersSnapshot / DebuggerVersionStore).
  if [[ "${SIMCTL_SHUTDOWN_ALL:-}" == "1" ]]; then
    xcrun simctl shutdown all >/dev/null 2>&1 || true
  fi

  if [[ -n "$sim_name" ]]; then
    # Do not shutdown the destination device here. `make test` runs unit tests on the
    # same simulator first; cycling power strands XCTest in a tight IDELaunchParametersSnapshot
    # loop (~30s) until the run times out. Set SIMCTL_RESET_DESTINATION=1 to force a reboot.
    if [[ "${SIMCTL_RESET_DESTINATION:-}" == "1" ]]; then
      xcrun simctl shutdown "$sim_name" >/dev/null 2>&1 || true
    fi
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
      -parallel-testing-enabled NO \
      -maximum-concurrent-test-simulator-destinations 1 \
      -quiet
  ) 2>&1 | tee "$LOG_FILE" || status=${PIPESTATUS[0]}

  return "$status"
}

is_known_launch_error() {
  # Note: Apple logs FBSOpenApplicationServiceErrorDomain (launch service) as well as
  # FBSOpenApplicationErrorDomain; both must match or retries never run.
  /usr/bin/grep -Eq \
    "FBSOpenApplicationServiceErrorDomain|FBSOpenApplicationErrorDomain|Simulator device failed to launch|Unknown application display identifier|xctrunner|NSMachErrorDomain|server died|ipc/mig|Code=-308|Failed to launch app with identifier" \
    "$LOG_FILE"
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
