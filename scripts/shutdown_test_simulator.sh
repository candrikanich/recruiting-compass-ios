#!/usr/bin/env bash
# Shut down the simulator a test run booted, so runs don't leave simulators piling up and
# grinding the Mac to a halt. Usage: shutdown_test_simulator.sh '<xcodebuild -destination>'
# Targets only the run's own device (never `simctl shutdown all` — other agents may be mid-run).
# KEEP_SIM=1 skips this when you want the simulator left up for debugging.
set -uo pipefail

destination="${1:-}"
[[ "${KEEP_SIM:-}" == "1" || -z "$destination" ]] && exit 0

device=""
if [[ "$destination" =~ id=([^,]+) ]]; then
  device="${BASH_REMATCH[1]}"
elif [[ "$destination" =~ name=([^,]+) ]]; then
  device="${BASH_REMATCH[1]}"
fi
[[ -n "$device" ]] && xcrun simctl shutdown "$device" >/dev/null 2>&1

# Parallel/clone runs boot throwaway devices in Xcode's separate "testing" device set.
xcrun simctl --set testing shutdown all >/dev/null 2>&1
xcrun simctl --set testing delete all >/dev/null 2>&1
exit 0
