#!/bin/sh
# Xcode Cloud: report the archive SDK (iPhone Duo check), then upload the archive's dSYMs to
# Sentry so crash stack traces are symbolicated.
# Needs SENTRY_AUTH_TOKEN (Secret) in the workflow environment — an org auth token with
# project:releases scope. Never fails the build: a missing upload only degrades stack traces.

set -u

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ] || [ -z "${CI_ARCHIVE_PATH:-}" ]; then
  exit 0
fi

# iPhone Duo (#219): only apps built with the iOS 27.1+ SDK get the full inner display; older
# SDKs are letterboxed. Report the archive SDK and warn (not fail, so hotfixes still ship).
MIN_DUO_SDK="27.1"
app_plist=$(ls -d "$CI_ARCHIVE_PATH"/Products/Applications/*.app/Info.plist 2>/dev/null | head -n 1)
sdk_name=unknown
if [ -f "$app_plist" ]; then
  sdk_name=$(/usr/libexec/PlistBuddy -c "Print :DTSDKName" "$app_plist" 2>/dev/null || echo unknown)
fi
echo "Archive built with SDK: $sdk_name"
if ! printf "%s\n" "${sdk_name#iphoneos}" | awk -v min="$MIN_DUO_SDK" -F. '
  $1 !~ /^[0-9]+$/ { exit 1 }
  { split(min, m, "."); exit !(($1 > m[1]) || ($1 == m[1] && $2 >= m[2])) }'; then
  echo "warning: archive SDK $sdk_name is below iphoneos$MIN_DUO_SDK — app will be letterboxed on iPhone Duo." >&2
fi

if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  echo "warning: SENTRY_AUTH_TOKEN not set — skipping Sentry dSYM upload." >&2
  exit 0
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
  brew install getsentry/tools/sentry-cli >/dev/null 2>&1 || {
    echo "warning: could not install sentry-cli — skipping dSYM upload." >&2
    exit 0
  }
fi

sentry-cli debug-files upload \
  --org chris-andrikanich \
  --project apple-ios \
  --include-sources \
  "$CI_ARCHIVE_PATH/dSYMs" \
  || echo "warning: Sentry dSYM upload failed." >&2

exit 0
