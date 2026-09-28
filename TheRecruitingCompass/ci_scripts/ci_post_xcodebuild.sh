#!/bin/sh
# Xcode Cloud: upload the archive's dSYMs to Sentry so crash stack traces are symbolicated.
# Needs SENTRY_AUTH_TOKEN (Secret) in the workflow environment — an org auth token with
# project:releases scope. Never fails the build: a missing upload only degrades stack traces.

set -u

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ] || [ -z "${CI_ARCHIVE_PATH:-}" ]; then
  exit 0
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
  --project recruiting-compass-ios \
  --include-sources \
  "$CI_ARCHIVE_PATH/dSYMs" \
  || echo "warning: Sentry dSYM upload failed." >&2

exit 0
