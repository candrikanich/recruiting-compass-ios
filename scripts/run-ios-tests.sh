#!/usr/bin/env bash
# Run this repo's iOS tests on a simulator, one run at a time across the whole Mac.
#
#   scripts/run-ios-tests.sh                                       # unit tests (UI tests skipped)
#   scripts/run-ios-tests.sh --only TheRecruitingCompassTests/FooTests [--only ...]
#   scripts/run-ios-tests.sh --ui | --all
#   scripts/run-ios-tests.sh --destination 'platform=iOS Simulator,name=iPhone 17'   # name= or id=
#   scripts/run-ios-tests.sh -- <extra xcodebuild args>
#
#   --wait <secs>      how long to wait for another run to finish (default 7200)
#   --fresh            erase the simulator before testing
#   --keep-sim         leave the simulator booted afterwards
#   --diagnostics      keep xcodebuild's failure diagnostics (about 13 min per failing run)
#   --verbose          stream all xcodebuild output, not just failures
#   --derived-data <p> default: <this checkout>/.build/DerivedData
#
# Every agent, worktree and the nightly share one lock (scripts/lib/ios-test-lock.sh). The build
# happens before the lock, so builds still overlap; only simulator time is serialized. By default
# tests run on the shared "TRC Agent iPhone" (created on first use) and it is shut down afterwards,
# pass or fail. Keep-listed simulators (~/.config/recruiting-compass/sim-sweep-keep) and ones that
# were already booted are left as they were. The agent simulator is created on the runtime named in
# ~/.config/recruiting-compass/agent-sim-runtime (e.g. com.apple.CoreSimulator.SimRuntime.iOS-18-6),
# else the newest; delete "TRC Agent iPhone" after changing that file so it is recreated.
#
# The last line is always "run-ios-tests: ** TEST SUCCEEDED **" or "run-ios-tests: ** TEST FAILED ** ...".
# Exit codes: xcodebuild's own (70 = invalid run, a simulator error); 75 = lock wait timed out;
# 124 = stalled (no output for 20 min); 64 = usage or unknown destination.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_DIR/TheRecruitingCompass/TheRecruitingCompass.xcodeproj"
SCHEME=TheRecruitingCompass
AGENT_SIM="TRC Agent iPhone"
KEEP_FILE="${SIM_SWEEP_KEEP_FILE:-$HOME/.config/recruiting-compass/sim-sweep-keep}"
RUNTIME_FILE="${RUN_IOS_TESTS_RUNTIME_FILE:-$HOME/.config/recruiting-compass/agent-sim-runtime}"
LOG_DIR="${RUN_IOS_TESTS_LOG_DIR:-$REPO_DIR/.build/run-ios-tests}"
STALL_SECONDS="${RUN_IOS_TESTS_STALL_SECONDS:-1200}"
MAX_ATTEMPTS=3
# Simulator runtime services left behind by killed runs; with nothing booted they only eat memory.
ORPHANS='CoreSimulator/Volumes/.*/(MTLCompilerService|SetStoreUpdateService)'
LAUNCH_ERRORS='FBSOpenApplicationServiceErrorDomain|FBSOpenApplicationErrorDomain|Simulator device failed to launch|Unknown application display identifier|NSMachErrorDomain|server died|ipc/mig|Code=-308|Failed to launch app with identifier'
SHOWN='error:|Test Case .* failed|\*\* TEST|Testing failed|Fatal error'

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

WAIT=7200 MODE=unit FRESH=0 KEEP_SIM=0 DIAGNOSTICS=0 VERBOSE=0 DESTINATION=""
DERIVED="$REPO_DIR/.build/DerivedData"
ONLY=()
EXTRA=()
while [ $# -gt 0 ]; do
  case "$1" in
    --unit) MODE=unit ;;
    --ui) MODE=ui ;;
    --all) MODE=all ;;
    --only) ONLY+=("-only-testing:${2:?--only needs a test identifier}"); shift ;;
    --destination) DESTINATION="${2:?--destination needs a value}"; shift ;;
    --wait) WAIT="${2:?--wait needs seconds}"; shift ;;
    --derived-data) DERIVED="${2:?--derived-data needs a path}"; shift ;;
    --fresh) FRESH=1 ;;
    --keep-sim) KEEP_SIM=1 ;;
    --diagnostics) DIAGNOSTICS=1 ;;
    --verbose) VERBOSE=1 ;;
    --) shift; EXTRA=("$@"); break ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
  shift
done

if [ ${#ONLY[@]} -gt 0 ]; then
  SELECTION=("${ONLY[@]}")
  LABEL="${ONLY[*]}"
else
  case "$MODE" in
    unit) SELECTION=(-skip-testing:TheRecruitingCompassUITests) ;;
    ui) SELECTION=(-only-testing:TheRecruitingCompassUITests) ;;
    all) SELECTION=() ;;
  esac
  LABEL="$MODE tests"
fi
TEST_FLAGS=(-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1)
[ "$DIAGNOSTICS" -eq 1 ] || TEST_FLAGS+=(-collect-test-diagnostics never)

finish() { # <exit code> <result>
  echo "run-ios-tests: $2"
  exit "$1"
}

# Prints "udid<TAB>name<TAB>state" for the newest available simulator matching an
# xcodebuild-style destination (id= or name=), or nothing.
find_sim() {
  xcrun simctl list devices available -j | /usr/bin/python3 -c '
import json, sys
pairs = dict(p.strip().split("=", 1) for p in sys.argv[1].split(",") if "=" in p)
want_id, want_name = pairs.get("id"), pairs.get("name")
for devices in reversed(list(json.load(sys.stdin)["devices"].values())):
    for d in devices:
        if (want_id and d["udid"] == want_id) or (not want_id and d["name"] == want_name):
            print(d["udid"], d["name"], d["state"], sep="\t")
            sys.exit()
' "$1"
}

# The configured runtime (newest iOS when unset or not installed), on "iPhone 17" when it supports
# one, else its newest plain-numbered iPhone.
create_agent_sim() {
  local runtime devicetype wanted=""
  [ -f "$RUNTIME_FILE" ] && wanted="$(tr -d '[:space:]' < "$RUNTIME_FILE")"
  read -r runtime devicetype < <(xcrun simctl list runtimes available -j | /usr/bin/python3 -c '
import json, re, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS"]
ios = ([r for r in runtimes if r["identifier"] == sys.argv[1]] or runtimes)[-1]
phones = [t for t in ios["supportedDeviceTypes"] if t["productFamily"] == "iPhone"]
exact = [t for t in phones if t["name"] == "iPhone 17"]
plain = [t for t in phones if re.fullmatch(r"iPhone \d+", t["name"])]
print(ios["identifier"], (exact or plain or phones)[-1]["identifier"])' "$wanted")
  UDID="$(xcrun simctl create "$AGENT_SIM" "$devicetype" "$runtime")"
  echo "run-ios-tests: created simulator $AGENT_SIM ($UDID)"
}

is_kept() {
  [ -f "$KEEP_FILE" ] || return 1
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$KEEP_FILE" | grep -v '^#' | grep -qxF -e "$UDID" -e "$NAME"
}

booted_count() {
  xcrun simctl list devices -j | /usr/bin/python3 -c '
import json, sys
print(sum(d["state"] == "Booted" for ds in json.load(sys.stdin)["devices"].values() for d in ds))'
}

preflight() {
  if [ "$(booted_count)" -eq 0 ] && pgrep -f "$ORPHANS" > /dev/null; then
    echo "run-ios-tests: nothing is booted; killing orphaned simulator runtime services"
    pkill -f "$ORPHANS" || true
  fi
  if pgrep -f '(^|/)xcodebuild .*test(-without-building)?( |$)' > /dev/null; then
    echo "run-ios-tests: warning: an xcodebuild test run outside this lock is still running (killed session or Xcode)"
  fi
  sysctl vm.swapusage | awk '{ t = $4; u = $7; sub(/M$/, "", t); sub(/M$/, "", u)
    if (t > 0 && u / t > 0.85) printf "run-ios-tests: warning: swap is %d%% full; runs may stall\n", 100 * u / t }'
}

boot_sim() {
  xcrun simctl boot "$UDID" > /dev/null 2>&1 || true
  xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1 || true
}

PRINTED=0
show_new_output() { # <log>
  local total
  total=$(wc -l < "$1" | tr -d ' ')
  [ "$total" -gt "$PRINTED" ] || return 0
  if [ "$VERBOSE" -eq 1 ]; then
    sed -n "$((PRINTED + 1)),${total}p" "$1"
  else
    sed -n "$((PRINTED + 1)),${total}p" "$1" | grep -E "$SHOWN" || true
  fi
  PRINTED=$total
}

STALLED=0
run_once() { # <attempt>; sets TEST_LOG, returns xcodebuild's exit code
  TEST_LOG="$LOG_DIR/$STAMP-test-$1.log"
  : > "$TEST_LOG"
  PRINTED=0
  xcodebuild test-without-building -project "$PROJECT" -scheme "$SCHEME" -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" ${SELECTION[@]+"${SELECTION[@]}"} "${TEST_FLAGS[@]}" \
    ${EXTRA[@]+"${EXTRA[@]}"} > "$TEST_LOG" 2>&1 &
  local xpid=$! rc=0 idle
  while kill -0 "$xpid" 2> /dev/null; do
    sleep 1
    show_new_output "$TEST_LOG"
    idle=$(($(date +%s) - $(stat -f %m "$TEST_LOG")))
    if [ "$idle" -ge "$STALL_SECONDS" ]; then
      STALLED=1
      kill -TERM "$xpid" 2> /dev/null || true
      for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$xpid" 2> /dev/null || break; sleep 1; done
      kill -9 "$xpid" 2> /dev/null || true
      break
    fi
  done
  wait "$xpid" || rc=$?
  show_new_output "$TEST_LOG"
  return "$rc"
}

# Resolve the simulator before building, so the build targets exactly what the tests will run on.
if [ -n "$DESTINATION" ]; then
  SIM="$(find_sim "$DESTINATION")"
  [ -n "$SIM" ] || { echo "run-ios-tests: no available simulator matches --destination '$DESTINATION'" >&2; exit 64; }
else
  SIM="$(find_sim "name=$AGENT_SIM")"
fi
UDID="$(printf '%s' "$SIM" | cut -f1)"
NAME="$(printf '%s' "$SIM" | cut -f2)"
NAME="${NAME:-$AGENT_SIM}"

mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
BUILD_LOG="$LOG_DIR/$STAMP-build.log"
# The agent simulator is created under the lock (so two first runs don't both create one);
# until then the build targets any simulator.
BUILD_DESTINATION="id=$UDID"
[ -n "$UDID" ] || BUILD_DESTINATION="generic/platform=iOS Simulator"
echo "run-ios-tests: building for testing (log: $BUILD_LOG)"
rc=0
xcodebuild build-for-testing -project "$PROJECT" -scheme "$SCHEME" -destination "$BUILD_DESTINATION" \
  -derivedDataPath "$DERIVED" -quiet ${EXTRA[@]+"${EXTRA[@]}"} > "$BUILD_LOG" 2>&1 || rc=$?
if [ "$rc" -ne 0 ]; then
  grep -E 'error:' "$BUILD_LOG" | tail -30 || true
  finish "$rc" "** TEST FAILED ** — build-for-testing exited $rc, no tests ran (log: $BUILD_LOG)"
fi

# shellcheck source=lib/ios-test-lock.sh
. "$SCRIPT_DIR/lib/ios-test-lock.sh"
SHUTDOWN_UDID=""
cleanup() {
  [ -z "$SHUTDOWN_UDID" ] || xcrun simctl shutdown "$SHUTDOWN_UDID" > /dev/null 2>&1 || true
  ios_test_lock_release
}
trap cleanup EXIT
ios_test_lock_acquire "$WAIT" "run-ios-tests $LABEL" ||
  finish 75 "** TEST FAILED ** — no tests ran: timed out after ${WAIT}s waiting for the iOS test lock"

preflight
[ -n "$UDID" ] || create_agent_sim
WAS_BOOTED=0
[ "$(find_sim "id=$UDID" | cut -f3)" = Booted ] && WAS_BOOTED=1
# Another session's already-booted simulator is theirs to shut down; ours always gets shut down.
if [ "$KEEP_SIM" -eq 0 ] && ! is_kept && { [ "$WAS_BOOTED" -eq 0 ] || [ "$NAME" = "$AGENT_SIM" ]; }; then
  SHUTDOWN_UDID="$UDID"
fi
if [ "$FRESH" -eq 1 ]; then
  xcrun simctl shutdown "$UDID" > /dev/null 2>&1 || true
  xcrun simctl erase "$UDID"
fi
echo "run-ios-tests: testing $LABEL on $NAME ($UDID)"
boot_sim

attempt=1
while :; do
  rc=0
  run_once "$attempt" || rc=$?
  [ "$STALLED" -eq 0 ] ||
    finish 124 "** TEST FAILED ** — STALLED: no output for ${STALL_SECONDS}s, run killed (log: $TEST_LOG)"
  [ "$rc" -ne 0 ] || finish 0 "** TEST SUCCEEDED ** (log: $TEST_LOG)"
  if [ "$attempt" -lt "$MAX_ATTEMPTS" ] && grep -Eq "$LAUNCH_ERRORS" "$TEST_LOG"; then
    echo "run-ios-tests: simulator launch error on attempt $attempt; rebooting $NAME and retrying"
    xcrun simctl shutdown "$UDID" > /dev/null 2>&1 || true
    boot_sim
    attempt=$((attempt + 1))
    continue
  fi
  [ "$rc" -ne 70 ] ||
    finish 70 "** TEST FAILED ** — INVALID RUN: xcodebuild exited 70 (simulator or launch error), not a test result (log: $TEST_LOG)"
  finish "$rc" "** TEST FAILED ** (xcodebuild exit $rc, log: $TEST_LOG)"
done
