#!/bin/zsh
# Records marketing clips: watches the marker files MarketingClipRecorderTests writes and runs
# `simctl io recordVideo` between each <clip>.start / <clip>.stop pair.
# Usage: scripts/record-marketing-clips.sh <simulator-udid> <output-dir> [clip,clip,...]
# Raw recordings land in <output-dir>/raw; <output-dir>/<clip>.mp4 has frozen stretches (XCUITest waiting on
# element queries) shortened to 0.9s by scripts/tighten-clip.swift.
# Requires local Supabase (seeded) and the local web API on :3003 — see the marketing README.
set -euo pipefail
SIM=${1:?simulator udid}
OUT=${2:?output dir}
ONLY=${3:-}
REPO=$(cd "$(dirname "$0")/.." && pwd)
MARKERS=${MARKER_DIR:-$(mktemp -d /tmp/rc-clip-markers.XXXXXX)}
mkdir -p "$OUT/raw"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null

xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 --dataNetwork wifi

watch_markers() {
  local recorder=""
  while true; do
    for start in "$MARKERS"/*.start(N); do
      local name=${${start:t}%.start}
      rm -f "$start"
      xcrun simctl io "$SIM" recordVideo --codec=h264 --force "$OUT/raw/$name.mp4" &
      recorder=$!
      echo "recording $name"
    done
    for stop in "$MARKERS"/*.stop(N); do
      rm -f "$stop"
      [[ -n $recorder ]] && kill -INT $recorder && wait $recorder || true
      recorder=""
      echo "saved $OUT/raw/${${stop:t}%.stop}.mp4"
    done
    sleep 0.2
  done
}
watch_markers &
WATCHER=$!
trap 'kill $WATCHER 2>/dev/null; pkill -INT -f "io $SIM recordVideo" 2>/dev/null || true' EXIT

cd "$REPO/TheRecruitingCompass"
set +e
# Parallel testing would run on a clone and shut this simulator down, so the recorder would capture nothing.
env TEST_RUNNER_RECORD_MARKETING_CLIPS=1 TEST_RUNNER_MARKETING_CLIP_MARKER_DIR="$MARKERS" \
  TEST_RUNNER_MARKETING_CLIPS="$ONLY" \
  xcodebuild test -scheme TheRecruitingCompass -destination "id=$SIM" -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:TheRecruitingCompassUITests/MarketingClipRecorderTests -quiet
STATUS=$?
set -e

swiftc -O "$REPO/scripts/tighten-clip.swift" -o "$MARKERS/tighten-clip"
for raw in "$OUT"/raw/*.mp4(N); do
  "$MARKERS/tighten-clip" "$raw" "$OUT/${raw:t}" 0.9
done
exit $STATUS
