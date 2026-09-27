#!/bin/sh
# Xcode Cloud: writes the gitignored Release.xcconfig from workflow environment variables.
# The "Generate config" build phase turns these into SupabaseConfig.generated.swift /
# PostHogConfigEmbedded.swift, and fails the build if the Supabase values are empty.
#
# Set in App Store Connect → Xcode Cloud → workflow → Environment (mark the keys Secret):
#   SUPABASE_ANON_KEY, API_BASE_URL, POSTHOG_API_KEY
# Optional: TURNSTILE_SITE_KEY (the build phase has a default).
#
# SUPABASE_URL is deliberately not written here: project.pbxproj pins it (production) at the
# project level for Debug and Release, which overrides any xcconfig value. SUPABASE_ANON_KEY
# must therefore be the production project's anon key.

set -eu

require() {
  eval "value=\${$1:-}"
  if [ -z "$value" ]; then
    echo "error: $1 is not set in the Xcode Cloud workflow environment." >&2
    exit 1
  fi
}

# xcconfig treats // as the start of a comment, so URLs spell their slashes via $(_SLASH).
xcconfig_url() {
  printf '%s' "$1" | sed 's#//#$(_SLASH)$(_SLASH)#g'
}

require SUPABASE_ANON_KEY
require API_BASE_URL
require POSTHOG_API_KEY

OUT="$CI_PRIMARY_REPOSITORY_PATH/TheRecruitingCompass/Release.xcconfig"

{
  echo "_SLASH = /"
  echo "SUPABASE_ANON_KEY = $SUPABASE_ANON_KEY"
  echo "API_BASE_URL = $(xcconfig_url "$API_BASE_URL")"
  echo "POSTHOG_API_KEY = $POSTHOG_API_KEY"
  if [ -n "${TURNSTILE_SITE_KEY:-}" ]; then
    echo "TURNSTILE_SITE_KEY = $TURNSTILE_SITE_KEY"
  fi
} > "$OUT"

echo "Wrote Release.xcconfig (anon key length ${#SUPABASE_ANON_KEY}, PostHog key length ${#POSTHOG_API_KEY})"
