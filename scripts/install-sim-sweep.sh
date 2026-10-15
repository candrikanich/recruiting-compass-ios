#!/usr/bin/env bash
# Installs (or removes) the launchd agent that runs scripts/sim_sweep.py hourly, so
# simulators that agents leave booted or behind get cleaned up without anyone
# running `simctl shutdown all`.
#
#   scripts/install-sim-sweep.sh               # install / refresh, hourly
#   scripts/install-sim-sweep.sh --uninstall
#
# Runs from the nightly E2E clone (~/ci/recruiting-compass-ios, kept on origin/main
# by nightly-local.sh --update), never from a worktree that may be deleted.
# Exempt a device by adding its name or UDID to ~/.config/recruiting-compass/sim-sweep-keep.
set -euo pipefail

LABEL="com.recruitingcompass.sim-sweep"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
IOS_CLONE="${NIGHTLY_E2E_CI_DIR:-$HOME/ci}/recruiting-compass-ios"
LOG_DIR="$HOME/Library/Logs/recruiting-compass"

if [ "${1:-}" = --uninstall ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed $LABEL."
  exit 0
fi

SWEEP="$IOS_CLONE/scripts/sim_sweep.py"
[ -f "$SWEEP" ] || { echo "missing $SWEEP (run scripts/e2e/install-nightly.sh first, or pull main there)" >&2; exit 1; }

mkdir -p "$LOG_DIR" "$(dirname "$PLIST")" "$HOME/.config/recruiting-compass"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$SWEEP</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>StandardOutPath</key><string>$LOG_DIR/sim-sweep.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/sim-sweep.log</string>
</dict>
</plist>
PLIST
plutil -lint "$PLIST" >/dev/null

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $LABEL: hourly from $IOS_CLONE."
echo "Preview:  /usr/bin/python3 $SWEEP --dry-run"
echo "Log:      $LOG_DIR/sim-sweep.log"
