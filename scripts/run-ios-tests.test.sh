#!/usr/bin/env bash
# Self-test for scripts/run-ios-tests.sh and scripts/lib/ios-test-lock.sh. macOS only (needs lockf).
# xcrun, xcodebuild, pgrep, pkill and sysctl are stubbed; the lock is real.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/run-ios-tests.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
export STUB_DIR="$TMP" PATH="$BIN:$PATH"
export IOS_TEST_LOCK_DIR="$TMP/state" SIM_SWEEP_KEEP_FILE="$TMP/keep" RUN_IOS_TESTS_LOG_DIR="$TMP/logs"
export RUN_IOS_TESTS_RUNTIME_FILE="$TMP/runtime"

AGENT=AAAAAAAA-0000-0000-0000-000000000001
PERF=AAAAAAAA-0000-0000-0000-000000000002
MINE=AAAAAAAA-0000-0000-0000-000000000003
CREATED=CCCCCCCC-0000-0000-0000-000000000009

cat > "$BIN/xcrun" <<'STUB'
#!/bin/bash
echo "xcrun $*" >> "$STUB_DIR/calls"
[ "$1" = simctl ] || exit 1
case "$2" in
  list) if [ "$3" = runtimes ]; then cat "$STUB_DIR/runtimes.json"; else cat "$STUB_DIR/devices.json"; fi ;;
  create) echo CCCCCCCC-0000-0000-0000-000000000009 ;;
esac
exit 0
STUB

cat > "$BIN/xcodebuild" <<'STUB'
#!/bin/bash
echo "xcodebuild $*" >> "$STUB_DIR/calls"
case " $* " in *" build-for-testing "*) echo "** TEST BUILD SUCCEEDED **"; exit "${STUB_BUILD_RC:-0}" ;; esac
n=$(( $(cat "$STUB_DIR/attempts" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$STUB_DIR/attempts"
echo "start ${STUB_TAG:-x}" >> "$STUB_DIR/sequence"
echo "Test Case '-[FooTests testBar]' started."
sleep "${STUB_TEST_SLEEP:-0}"
echo "end ${STUB_TAG:-x}" >> "$STUB_DIR/sequence"
if [ "$n" -le "${STUB_LAUNCH_ERROR_ATTEMPTS:-0}" ]; then
  echo "Error Domain=FBSOpenApplicationServiceErrorDomain Code=1"
  echo "** TEST FAILED **"
  exit 65
fi
rc=${STUB_TEST_RC:-0}
if [ "$rc" -eq 0 ]; then echo "** TEST SUCCEEDED **"; else echo "** TEST FAILED **"; fi
exit "$rc"
STUB

cat > "$BIN/pgrep" <<'STUB'
#!/bin/bash
[ -n "${STUB_ORPHANS:-}" ] && { echo 4242; exit 0; }
exit 1
STUB
cat > "$BIN/pkill" <<'STUB'
#!/bin/bash
echo "pkill $*" >> "$STUB_DIR/calls"
STUB
cat > "$BIN/sysctl" <<'STUB'
#!/bin/bash
echo "vm.swapusage: total = 1000.00M  used = ${STUB_SWAP_USED:-100}.00M  free = 900.00M  (encrypted)"
STUB
chmod +x "$BIN"/*

cat > "$TMP/runtimes.json" <<'JSON'
{"runtimes":[{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-18-6","platform":"iOS","isAvailable":true,
  "supportedDeviceTypes":[{"name":"iPhone 16","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-16","productFamily":"iPhone"}]},
 {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-2","platform":"iOS","isAvailable":true,
  "supportedDeviceTypes":[{"name":"iPhone 17","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17","productFamily":"iPhone"}]}]}
JSON

devices() { # <agent present: yes|no> <state of "My iPhone">
  local agent=""
  [ "$1" = yes ] && agent="{\"udid\":\"$AGENT\",\"name\":\"TRC Agent iPhone\",\"state\":\"Shutdown\",\"isAvailable\":true},"
  cat > "$TMP/devices.json" <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-2":[$agent
  {"udid":"$PERF","name":"Perf iPhone 17","state":"Shutdown","isAvailable":true},
  {"udid":"$MINE","name":"My iPhone","state":"$2","isAvailable":true}]}}
JSON
}

reset() {
  rm -rf "$TMP/runtime" "$TMP/calls" "$TMP/sequence" "$TMP/attempts" "$TMP/out" "$TMP"/out-* "$TMP/state" "$TMP/logs"
  devices yes Shutdown
  printf '# keep\nPerf iPhone 17\n' > "$TMP/keep"
}

run() { "$SCRIPT" "$@" > "$TMP/out" 2>&1; echo $?; }

failures=0
check() { # <label> <command...>
  local label="$1"; shift
  if ! "$@"; then
    echo "FAIL: $label"
    sed 's/^/    | /' "$TMP/out" 2>/dev/null | tail -15
    failures=$((failures + 1))
  fi
}
called() { grep -qF -- "$1" "$TMP/calls"; }
not_called() { ! grep -qF -- "$1" "$TMP/calls"; }
test_call() { grep -F 'test-without-building' "$TMP/calls" | head -1; }
test_call_has() { test_call | grep -qF -- "$1"; }
test_call_lacks() { ! test_call | grep -qF -- "$1"; }
out_has() { grep -qF -- "$1" "$TMP/out"; }
last_line_has() { tail -1 "$TMP/out" | grep -qF -- "$1"; }
eq() { [ "$1" = "$2" ]; }

reset
rc=$(run)
check "default run passes" eq "$rc" 0
check "builds before testing" eq "$(grep -oE 'build-for-testing|test-without-building' "$TMP/calls" | tr '\n' ' ')" \
  "build-for-testing test-without-building "
check "serial testing" test_call_has "-parallel-testing-enabled NO"
check "one destination at a time" test_call_has "-maximum-concurrent-test-simulator-destinations 1"
check "no diagnostics collection" test_call_has "-collect-test-diagnostics never"
check "unit tests by default" test_call_has "-skip-testing:TheRecruitingCompassUITests"
check "targets the agent simulator" test_call_has "-destination id=$AGENT"
check "boots it" called "simctl boot $AGENT"
check "shuts it down afterwards" called "simctl shutdown $AGENT"
check "final line is the result" last_line_has "** TEST SUCCEEDED **"
check "releases the lock owner file" eq "$(ls "$TMP/state" | grep -c owner)" 0

reset
run --only TheRecruitingCompassTests/FooTests --only TheRecruitingCompassTests/BarTests > /dev/null
check "--only selects classes" test_call_has \
  "-only-testing:TheRecruitingCompassTests/FooTests -only-testing:TheRecruitingCompassTests/BarTests"
check "--only drops the default skip" test_call_lacks "-skip-testing"

reset
run --ui > /dev/null
check "--ui runs only UI tests" test_call_has "-only-testing:TheRecruitingCompassUITests"

reset
run --diagnostics > /dev/null
check "--diagnostics re-enables collection" test_call_lacks "-collect-test-diagnostics never"

reset
run -- -test-timeouts-enabled YES > /dev/null
check "extra args reach xcodebuild" test_call_has "-test-timeouts-enabled YES"

reset
rc=$(STUB_TEST_RC=65 run)
check "failure passes the exit code through" eq "$rc" 65
check "failure still shuts the simulator down" called "simctl shutdown $AGENT"
check "failure final line" last_line_has "** TEST FAILED **"

reset
rc=$(STUB_TEST_RC=70 run)
check "rc 70 passes through" eq "$rc" 70
check "rc 70 is an invalid run, not a test result" out_has "INVALID RUN"

reset
rc=$(STUB_BUILD_RC=65 run)
check "build failure exits non-zero" eq "$rc" 65
check "build failure never takes the lock or boots" not_called "simctl boot"
check "build failure final line" last_line_has "** TEST FAILED **"

reset
rc=$(STUB_LAUNCH_ERROR_ATTEMPTS=1 run)
check "known launch error is retried" eq "$rc" 0
check "retried once" eq "$(cat "$TMP/attempts")" 2

reset
rc=$(STUB_LAUNCH_ERROR_ATTEMPTS=5 run)
check "gives up after three attempts" eq "$(cat "$TMP/attempts")" 3
check "and fails" eq "$rc" 65

reset
run --destination 'platform=iOS Simulator,name=Perf iPhone 17' > /dev/null
check "named destination resolves to its id" test_call_has "-destination id=$PERF"
check "keep-listed simulator is never shut down" not_called "simctl shutdown $PERF"

reset
devices yes Booted
run --destination "id=$MINE" > /dev/null
check "a simulator that was already booted is left booted" not_called "simctl shutdown $MINE"

reset
run --keep-sim > /dev/null
check "--keep-sim leaves the simulator up" not_called "simctl shutdown $AGENT"

reset
run --fresh > /dev/null
check "--fresh erases first" called "simctl erase $AGENT"

reset
devices no Shutdown
run > /dev/null
check "creates the agent simulator when missing" called "simctl create TRC Agent iPhone"
check "and tests on it" test_call_has "-destination id=$CREATED"
check "on the newest runtime by default" called "SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-27-2"

reset
devices no Shutdown
echo com.apple.CoreSimulator.SimRuntime.iOS-18-6 > "$TMP/runtime"
run > /dev/null
check "or on the configured runtime, with an iPhone it supports" \
  called "SimDeviceType.iPhone-16 com.apple.CoreSimulator.SimRuntime.iOS-18-6"

reset
rc=$(run --destination 'name=No Such iPhone')
check "unknown destination is an error" eq "$rc" 64

reset
rc=$(STUB_ORPHANS=1 run)
check "kills orphaned simulator runtime services when nothing is booted" called "pkill -f"

reset
STUB_SWAP_USED=950 run > /dev/null
check "warns when swap is nearly full" out_has "swap"

reset
rc=$(RUN_IOS_TESTS_STALL_SECONDS=2 STUB_TEST_SLEEP=6 run)
check "a silent run is killed" eq "$rc" 124
check "and reported as stalled" out_has "STALLED"
check "stall final line" last_line_has "** TEST FAILED **"
sleep 5 # let the stub's orphaned sleep finish

# Two runs at once: the second waits for the first instead of overlapping.
reset
STUB_TAG=A STUB_TEST_SLEEP=3 "$SCRIPT" > "$TMP/out-a" 2>&1 &
first=$!
sleep 1
STUB_TAG=B "$SCRIPT" > "$TMP/out-b" 2>&1 &
second=$!
wait "$first" "$second"
check "concurrent runs are serialized" eq "$(tr '\n' ' ' < "$TMP/sequence")" "start A end A start B end B "
check "the waiting run names the holder" grep -q "waiting for the iOS test lock" "$TMP/out-b"

# Waiting past --wait gives up with EX_TEMPFAIL instead of overlapping.
reset
mkdir -p "$TMP/state"
lockf -k "$TMP/state/ios-test.lock" sleep 4 &
holder=$!
sleep 0.5
rc=$(run --wait 1)
check "lock timeout exits 75" eq "$rc" 75
check "lock timeout says so" out_has "Timed out"
check "lock timeout never boots" not_called "simctl boot"
wait "$holder"

# A killed run releases the lock.
reset
set -m
STUB_TEST_SLEEP=30 "$SCRIPT" > "$TMP/out-a" 2>&1 &
group=$!
set +m
for _ in $(seq 1 50); do [ -s "$TMP/state/ios-test.lock.owner" ] && break; sleep 0.2; done
victim=$(sed -n 's/^pid=//p' "$TMP/state/ios-test.lock.owner")
kill -9 "$victim"
rc=$(run --wait 5)
check "a killed run releases the lock" eq "$rc" 0
{ kill -9 -- "-$group"; wait "$group"; } 2>/dev/null

if [ "$failures" -gt 0 ]; then
  echo "$failures run-ios-tests case(s) failed"
  exit 1
fi
echo "run-ios-tests: all cases pass"
