#!/usr/bin/env bash
# Guards the build-generated config files. The "Generate config" build phase rewrites
# them from Release.xcconfig on every build, so a blanket `git add` can sweep real
# values over the committed stubs. Shared by .githooks/pre-commit and CI so the two
# can't drift.
#
#   check-generated-config.sh paths   < list of changed paths   (hook + CI)
#   check-generated-config.sh stub [repo-root]                  (CI: file shape)
#
# Intentional stub change: ALLOW_GENERATED_CONFIG=1 (hook) or the
# `allow-generated-config` PR label (CI).
set -euo pipefail

GENERATED_CONFIG='/Core/Services/(SupabaseConfig\.generated|PostHogConfigEmbedded|TurnstileConfig\.generated)\.swift$'
SUPABASE_STUB='Core/Services/SupabaseConfig.generated.swift'

case "${1:-paths}" in
  paths)
    hits=$(grep -E "$GENERATED_CONFIG" || true)
    if [ -n "$hits" ]; then
      echo "$hits"
      exit 1
    fi
    ;;
  stub)
    root="${2:-.}"
    file=$(find "$root" -path "*/$SUPABASE_STUB" -not -path '*/node_modules/*' | head -1)
    [ -n "$file" ] || { echo "$SUPABASE_STUB not found under $root"; exit 1; }
    # The only file whose committed shape is placeholder values; the other two
    # hold public client keys by design.
    if ! grep -q 'urlString = "https://placeholder.supabase.co"' "$file" ||
       ! grep -q 'anonKey = "placeholder-key"' "$file" ||
       ! grep -q 'apiBaseURL = ""' "$file"; then
      echo "$file is not the committed placeholder stub"
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 paths|stub [repo-root]" >&2
    exit 2
    ;;
esac
