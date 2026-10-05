#!/usr/bin/env bash
# Installs (or removes) the launchd agent that runs the iOS E2E UITests nightly
# on this Mac: scripts/e2e/nightly-local.sh --update --report.
#
#   scripts/e2e/install-nightly.sh               # install / refresh, 02:30 daily
#   scripts/e2e/install-nightly.sh --uninstall
#
# The agent runs from dedicated clones under ~/ci (it hard-resets them every
# night), never from a working checkout. Needs: Xcode, Docker Desktop, the
# Supabase CLI, node/npm, and gh signed in (for the failure issue). A Mac that
# is asleep at 02:30 runs the job when it wakes.
set -euo pipefail

LABEL="com.recruitingcompass.ios-nightly-e2e"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CI_DIR="${NIGHTLY_E2E_CI_DIR:-$HOME/ci}"
IOS_CLONE="$CI_DIR/recruiting-compass-ios"
WEB_CLONE="$CI_DIR/recruiting-compass-web"
LOG_DIR="$HOME/Library/Logs/recruiting-compass"

if [ "${1:-}" = --uninstall ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed $LABEL (clones in $CI_DIR left in place)."
  exit 0
fi

for tool in xcodebuild docker supabase node npm gh git; do
  command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

mkdir -p "$CI_DIR" "$LOG_DIR" "$(dirname "$PLIST")"
[ -d "$IOS_CLONE/.git" ] || gh repo clone candrikanich/recruiting-compass-ios "$IOS_CLONE"
[ -d "$WEB_CLONE/.git" ] || gh repo clone candrikanich/recruiting-compass-web "$WEB_CLONE" -- --branch develop

# launchd starts agents with a bare PATH; give it the directories the tools
# live in now (Homebrew, Docker, nvm's node).
path=""
for tool in node supabase docker gh git xcodebuild; do
  dir="$(dirname "$(command -v "$tool")")"
  case ":$path:" in *":$dir:"*) ;; *) path="${path:+$path:}$dir" ;; esac
done
path="$path:/usr/bin:/bin:/usr/sbin:/sbin"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$IOS_CLONE/scripts/e2e/nightly-local.sh</string>
    <string>--update</string>
    <string>--report</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$path</string>
    <key>NIGHTLY_E2E_WEB_DIR</key><string>$WEB_CLONE</string>
  </dict>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>2</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <key>StandardOutPath</key><string>$LOG_DIR/ios-nightly-e2e.launchd.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/ios-nightly-e2e.launchd.log</string>
</dict>
</plist>
PLIST
plutil -lint "$PLIST" >/dev/null

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed $LABEL: 02:30 daily from $IOS_CLONE."
echo "Run now:  launchctl kickstart gui/$(id -u)/$LABEL"
echo "Logs:     $LOG_DIR/ios-nightly-e2e-*.log"
