#!/usr/bin/env bash
# iOS E2E UITests on this Mac against a throwaway local Supabase stack.
#
#   scripts/e2e/nightly-local.sh                       # smoke suite, this checkout as-is
#   scripts/e2e/nightly-local.sh --suite full
#   scripts/e2e/nightly-local.sh --only-testing TheRecruitingCompassUITests/AddSchoolE2ETests
#   scripts/e2e/nightly-local.sh --update --report     # what the launchd agent runs
#
# Replaces the GitHub-hosted nightly job, which needed the hosted E2E Supabase
# project (macOS runners have no Docker). This repo is public, so the Mac is
# deliberately NOT a GitHub runner for it; launchd runs this instead
# (scripts/e2e/install-nightly.sh).
#
# --update  fast-forwards this checkout to origin/main and the web checkout to
#           origin/develop first (hard reset: only for the dedicated clones).
# --report  opens/updates the "Nightly iOS E2E (local) is failing" issue on
#           failure and closes it on the next pass.
#
# Database: the web repo's scripts/e2e/local-supabase.sh (all web migrations),
# as project rc-ios-e2e on ports 4632x so it can run alongside a web CI job
# (4532x) or a dev stack (5432x). Simulator: a dedicated "Nightly E2E iPhone",
# erased every run, so a developer's own simulators are never touched.
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEB_DIR="${NIGHTLY_E2E_WEB_DIR:-$HOME/ci/recruiting-compass-web}"
STATE_DIR="${NIGHTLY_E2E_STATE_DIR:-$HOME/Library/Application Support/recruiting-compass/ios-nightly-e2e}"
LOG_DIR="${NIGHTLY_E2E_LOG_DIR:-$HOME/Library/Logs/recruiting-compass}"
ISSUE_REPO="candrikanich/recruiting-compass-ios"
ISSUE_TITLE="Nightly iOS E2E (local) is failing"
SIM_NAME="Nightly E2E iPhone"
# Per-test allowances cap a single test at 300s, so 10 quiet minutes means the
# run is wedged, not slow.
STALL_SECONDS=600

export E2E_SUPABASE_PROJECT_ID=rc-ios-e2e
export E2E_SUPABASE_PORT_PREFIX=463
export E2E_SUPABASE_WORKDIR="$STATE_DIR/supabase"

UPDATE=0
REPORT=0
SUITE=smoke
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --update) UPDATE=1 ;;
    --report) REPORT=1 ;;
    --suite) SUITE="$2"; shift ;;
    --only-testing) ONLY="$2"; shift ;;
    --no-update) ;; # set by the re-exec below
    *) echo "usage: $0 [--update] [--report] [--suite smoke|full] [--only-testing <id>]" >&2; exit 64 ;;
  esac
  shift
done

mkdir -p "$STATE_DIR" "$LOG_DIR"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/ios-nightly-e2e-$RUN_ID.log"
exec > >(tee -a "$LOG") 2>&1

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

if [ "$UPDATE" -eq 1 ]; then
  log "Updating $IOS_DIR to origin/main and $WEB_DIR to origin/develop"
  git -C "$IOS_DIR" fetch --quiet origin main
  git -C "$IOS_DIR" reset --quiet --hard origin/main
  git -C "$WEB_DIR" fetch --quiet origin develop
  git -C "$WEB_DIR" reset --quiet --hard origin/develop
  # Run the freshly pulled copy of this script, not the one bash already read.
  args=(--no-update --suite "$SUITE")
  [ "$REPORT" -eq 1 ] && args+=(--report)
  [ -n "$ONLY" ] && args+=(--only-testing "$ONLY")
  exec "$IOS_DIR/scripts/e2e/nightly-local.sh" "${args[@]}"
fi

LOCAL_SUPABASE="$WEB_DIR/scripts/e2e/local-supabase.sh"
if [ ! -x "$LOCAL_SUPABASE" ]; then
  log "No web checkout with scripts/e2e/local-supabase.sh at $WEB_DIR (set NIGHTLY_E2E_WEB_DIR)."
  exit 1
fi

LOCK="$STATE_DIR/run.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  log "Another run holds $LOCK; exiting."
  exit 0
fi

SIM_UDID=""
cleanup() {
  "$LOCAL_SUPABASE" stop || true
  [ -n "$SIM_UDID" ] && xcrun simctl shutdown "$SIM_UDID" >/dev/null 2>&1 || true
  rmdir "$LOCK" 2>/dev/null || true
  # Keep two weeks of logs.
  find "$LOG_DIR" -name 'ios-nightly-e2e-*.log' -mtime +14 -delete 2>/dev/null || true
}
trap cleanup EXIT

ensure_docker() {
  docker info >/dev/null 2>&1 && return 0
  log "Docker is not running; starting Docker Desktop"
  open -a Docker
  for _ in $(seq 1 60); do
    sleep 3
    docker info >/dev/null 2>&1 && return 0
  done
  log "Docker did not come up within 3 minutes"
  return 1
}

# Callers use `fn || fail`, which disables set -e inside fn, so every step
# below returns its own failure explicitly.
start_stack() {
  "$LOCAL_SUPABASE" start || return 1
  local key value
  while IFS='=' read -r key value; do
    case "$key" in
      TEST_SUPABASE_URL) SUPABASE_URL="$value" ;;
      NUXT_PUBLIC_SUPABASE_ANON_KEY) SUPABASE_ANON_KEY="$value" ;;
      SUPABASE_SERVICE_ROLE_KEY) SUPABASE_SERVICE_ROLE_KEY="$value" ;;
    esac
  done < <("$LOCAL_SUPABASE" env)
  [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ] && [ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ] || return 1
  log "Local Supabase at $SUPABASE_URL"
}

seed() {
  (
    cd "$IOS_DIR/scripts" &&
      npm ci --silent &&
      SUPABASE_URL="$SUPABASE_URL" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" npm run seed:e2e
  )
}

# The project references the gitignored Release.xcconfig; tests don't read it
# (they inject the stack via TEST_RUNNER_E2E_SUPABASE_*), so placeholders do.
ensure_xcconfig() {
  local xcconfig="$IOS_DIR/TheRecruitingCompass/Release.xcconfig"
  [ -f "$xcconfig" ] && return 0
  cat > "$xcconfig" <<'XCCONFIG'
_SLASH = /
SUPABASE_URL = https:$(_SLASH)$(_SLASH)ci-placeholder.supabase.co
SUPABASE_ANON_KEY = ci_placeholder_key
API_BASE_URL = https:$(_SLASH)$(_SLASH)myrecruitingcompass.com
XCCONFIG
}

ensure_simulator() {
  SIM_UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == name:
            print(d["udid"]); sys.exit()
' "$SIM_NAME")"
  if [ -z "$SIM_UDID" ]; then
    # Newest iOS runtime, and an iPhone that runtime supports: "iPhone 17" when
    # present, else its newest plain-numbered iPhone.
    local runtime devicetype
    read -r runtime devicetype < <(xcrun simctl list runtimes available -j | python3 -c '
import json, re, sys
ios = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS"][-1]
phones = [t for t in ios["supportedDeviceTypes"] if t["productFamily"] == "iPhone"]
exact = [t for t in phones if t["name"] == "iPhone 17"]
plain = [t for t in phones if re.fullmatch(r"iPhone \d+", t["name"])]
print(ios["identifier"], (exact or plain or phones)[-1]["identifier"])')
    SIM_UDID="$(xcrun simctl create "$SIM_NAME" "$devicetype" "$runtime")" || return 1
    log "Created simulator $SIM_NAME ($devicetype, $runtime)"
  fi
  [ -n "$SIM_UDID" ] || return 1
  log "Simulator $SIM_NAME: $SIM_UDID"
}

# Erase + boot only our own device. A full CoreSimulatorService restart would
# also kill a developer's open simulators, so it is reserved for retries after
# a wedge.
reset_sim() {
  local hard="${1:-}"
  if [ "$hard" = hard ]; then
    xcrun simctl shutdown all || true
    killall -9 CoreSimulatorService || true
    sleep 5
  else
    xcrun simctl shutdown "$SIM_UDID" >/dev/null 2>&1 || true
  fi
  xcrun simctl erase "$SIM_UDID" || true
  xcrun simctl boot "$SIM_UDID" || true
  xcrun simctl bootstatus "$SIM_UDID" -b || true
}

DERIVED="$STATE_DIR/DerivedData"
RESULTS="$STATE_DIR/results"

build_for_testing() {
  xcodebuild build-for-testing \
    -project "$IOS_DIR/TheRecruitingCompass/TheRecruitingCompass.xcodeproj" \
    -scheme TheRecruitingCompass \
    -destination "id=$SIM_UDID" \
    -derivedDataPath "$DERIVED" \
    -quiet
}

ONLY_TESTING=()
select_tests() {
  if [ -n "$ONLY" ]; then
    ONLY_TESTING=("-only-testing:$ONLY")
  elif [ "$SUITE" = full ]; then
    ONLY_TESTING=(-only-testing:TheRecruitingCompassUITests)
  else
    local class
    while IFS= read -r class; do
      # A name xcodebuild can't match runs zero tests and still exits 0.
      if ! grep -rqs "class $class: XCTestCase" "$IOS_DIR/TheRecruitingCompass/TheRecruitingCompassUITests"; then
        log "Smoke suite lists $class, which is not a UI test class"
        return 1
      fi
      ONLY_TESTING+=("-only-testing:TheRecruitingCompassUITests/$class")
    done < <(grep -Ev '^(#|$)' "$IOS_DIR/scripts/ci/e2e-smoke-suite.txt")
  fi
}

run_attempt() {
  local attempt=$1
  local alog="$RESULTS/attempt-$attempt.log"
  rm -rf "$RESULTS/attempt-$attempt.xcresult" "$RESULTS/stalled" "$RESULTS/login-blocked"
  : > "$alog"
  set +e
  # TEST_RUNNER_ is how a variable reaches the test runner: xcodebuild strips
  # the prefix, and E2ETestEnvironment reads E2E_SUPABASE_URL / _ANON_KEY.
  TEST_RUNNER_E2E_SUPABASE_URL="$SUPABASE_URL" \
  TEST_RUNNER_E2E_SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  xcodebuild test-without-building \
    -project "$IOS_DIR/TheRecruitingCompass/TheRecruitingCompass.xcodeproj" \
    -scheme TheRecruitingCompass \
    -destination "id=$SIM_UDID" \
    -derivedDataPath "$DERIVED" \
    "${ONLY_TESTING[@]}" \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 120 \
    -maximum-test-execution-time-allowance 300 \
    -resultBundlePath "$RESULTS/attempt-$attempt.xcresult" \
    > "$alog" 2>&1 &
  local xpid=$!
  (
    while kill -0 "$xpid" 2>/dev/null; do
      sleep 30
      idle=$(( $(date +%s) - $(stat -f %m "$alog") ))
      if [ "$idle" -ge "$STALL_SECONDS" ]; then
        echo "no xcodebuild output for ${idle}s — killing stalled attempt $attempt"
        touch "$RESULTS/stalled"
        kill -9 "$xpid" 2>/dev/null
        break
      fi
      # Every E2E test XCTSkips when sign-in fails; a run that opens with only
      # those can't sign in at all and would burn hours saying so.
      blocked=$(grep -c "Test skipped - Login failed" "$alog" || true)
      passed=$(grep -cE "^Test Case .* passed" "$alog" || true)
      if [ "$blocked" -ge 5 ] && [ "$passed" -eq 0 ]; then
        echo "first $blocked tests all skipped on 'Login failed' — the app cannot sign in; stopping"
        touch "$RESULTS/login-blocked"
        kill -9 "$xpid" 2>/dev/null
        break
      fi
    done
  ) &
  local wpid=$!
  wait "$xpid"; local rc=$?
  kill "$wpid" 2>/dev/null
  wait "$wpid" 2>/dev/null || true
  set -e
  grep -E "^Test Case .* (passed|failed|skipped)|error:|\*\* TEST" "$alog" | tail -60 || true
  return $rc
}

run_tests() {
  rm -rf "$RESULTS"; mkdir -p "$RESULTS"
  local attempt rc finished
  for attempt in 1 2 3; do
    log "UITests attempt $attempt"
    rc=0
    run_attempt "$attempt" || rc=$?
    [ "$rc" -eq 0 ] && return 0
    [ -f "$RESULTS/login-blocked" ] && return 1
    # Retry only infrastructure failures (stalled, or died before any test
    # finished); real test failures fail the run.
    finished=$(grep -cE "^Test Case .* (passed|failed|skipped)" "$RESULTS/attempt-$attempt.log" || true)
    if [ ! -f "$RESULTS/stalled" ] && [ "$finished" -gt 0 ]; then
      log "UITests failed (xcodebuild exit $rc) after $finished tests ran"
      return "$rc"
    fi
    log "Attempt $attempt stalled or never started a test; hard-resetting the simulator stack"
    reset_sim hard
  done
  log "UITests could not complete a run in 3 attempts"
  return 1
}

SUMMARY="no result bundle"
summarize() {
  local bundle
  bundle="$(ls -td "$RESULTS"/attempt-*.xcresult 2>/dev/null | head -1 || true)"
  [ -f "$bundle/Info.plist" ] || return 1
  xcrun xcresulttool get test-results summary --path "$bundle" > "$RESULTS/summary.json"
  PASSED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["passedTests"])' "$RESULTS/summary.json")
  FAILED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["failedTests"])' "$RESULTS/summary.json")
  SKIPPED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["skippedTests"])' "$RESULTS/summary.json")
  SUMMARY="$PASSED passed, $FAILED failed, $SKIPPED skipped"
  # Tests XCTSkip when login fails, so nothing passing is a broken
  # environment reporting green, not a passing suite.
  [ "$PASSED" -gt 0 ]
}

report() {
  local status=$1 detail=$2
  [ "$REPORT" -eq 1 ] || return 0
  local sha existing body
  sha="$(git -C "$IOS_DIR" rev-parse --short HEAD)"
  existing="$(gh issue list -R "$ISSUE_REPO" --state open --search "\"$ISSUE_TITLE\" in:title" --json number -q '.[0].number' || true)"
  if [ "$status" = pass ]; then
    if [ -n "$existing" ]; then
      gh issue close "$existing" -R "$ISSUE_REPO" --comment "Passed on $(date +%Y-%m-%d) at \`$sha\` ($detail)."
    fi
    return 0
  fi
  body="Nightly local iOS E2E ($SUITE) failed on $(date +%Y-%m-%d) at \`$sha\`: $detail.
Log on the Mac: \`${LOG/#$HOME/~}\`; result bundles in \`${RESULTS/#$HOME/~}\`."
  if [ -n "$existing" ]; then
    gh issue comment "$existing" -R "$ISSUE_REPO" --body "$body"
  else
    gh issue create -R "$ISSUE_REPO" --title "$ISSUE_TITLE" --label bug --body "$body"
  fi
  osascript -e "display notification \"$detail\" with title \"$ISSUE_TITLE\"" >/dev/null 2>&1 || true
}

fail() {
  log "FAILED: $1"
  report fail "$1" || true
  exit 1
}

log "iOS E2E ($SUITE) at $(git -C "$IOS_DIR" rev-parse --short HEAD), web $(git -C "$WEB_DIR" rev-parse --short HEAD)"
ensure_docker || fail "Docker Desktop did not start"
start_stack || fail "local Supabase stack did not start"
seed || fail "seed:e2e failed"
ensure_xcconfig
ensure_simulator || fail "could not find or create the $SIM_NAME simulator"
reset_sim
log "Building for testing"
build_for_testing || fail "build-for-testing failed"
select_tests || fail "smoke suite list is stale"
tests_rc=0
run_tests || tests_rc=$?
summarize_ok=0
summarize || summarize_ok=$?
log "Result: $SUMMARY (xcodebuild exit $tests_rc)"
if [ "$tests_rc" -ne 0 ] || [ "$summarize_ok" -ne 0 ]; then
  fail "$SUMMARY"
fi
report pass "$SUMMARY"
log "PASSED: $SUMMARY"
