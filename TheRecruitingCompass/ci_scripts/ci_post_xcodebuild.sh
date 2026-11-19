#!/bin/sh
# Xcode Cloud: report the archive SDK (iPhone Duo check), upload the archive's dSYMs to Sentry so
# crash stack traces are symbolicated, then create/finalize the Sentry release with commits attached
# (suspect commits, "resolve in next release").
# Needs SENTRY_AUTH_TOKEN (Secret) in the workflow environment — an org auth token with
# project:releases and org:read scopes (see docs/RELEASE.md). Never fails the build: a missing
# upload only degrades stack traces and a missing release only loses commit attribution.

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

# Release name must match what the Cocoa SDK reports: <bundle id>@<version>+<build>.
plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$app_plist" 2>/dev/null; }
bundle_id=$(plist_value CFBundleIdentifier)
short_version=$(plist_value CFBundleShortVersionString)
build_number=$(plist_value CFBundleVersion)
if [ -z "$bundle_id" ] || [ -z "$short_version" ] || [ -z "$build_number" ]; then
  echo "warning: could not read bundle id/version/build from the archive — skipping Sentry release." >&2
  exit 0
fi
release="$bundle_id@$short_version+$build_number"
echo "Sentry release: $release"

sentry_release() {
  sentry-cli releases --org chris-andrikanich --project apple-ios "$@"
}

sentry_release new "$release" || echo "warning: Sentry release creation failed." >&2

# Run from the checkout so sentry-cli can read the git history. --auto needs the repo linked via
# Sentry's GitHub integration; --local sends the commits from git when it is not.
(
  cd "${CI_PRIMARY_REPOSITORY_PATH:-.}" || exit 1
  sentry_release set-commits "$release" --auto \
    || sentry_release set-commits "$release" --local --ignore-missing
) || echo "warning: could not attach commits to Sentry release $release." >&2

sentry_release finalize "$release" || echo "warning: Sentry release finalize failed." >&2

exit 0
