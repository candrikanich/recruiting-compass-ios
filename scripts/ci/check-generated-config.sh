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
SUPABASE_STUB_SHA256='4e973927b1f6aedbf9f221ca691ab01ffd874827ad33e73b858b5bdf3bf06123'

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
    files=$(find "$root" -path "*/$SUPABASE_STUB" -not -path '*/node_modules/*')
    count=$(printf '%s' "$files" | grep -c . || true)
    if [ "$count" -ne 1 ]; then
      echo "expected exactly one $SUPABASE_STUB under $root, found $count"
      exit 1
    fi
    # Byte-for-byte: a presence grep would pass a real value hidden next to the
    # placeholder strings. A deliberate stub edit updates this hash in the same PR.
    actual=$(shasum -a 256 "$files" | cut -d' ' -f1)
    if [ "$actual" != "$SUPABASE_STUB_SHA256" ]; then
      echo "$files differs from the committed placeholder stub"
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 paths|stub [repo-root]" >&2
    exit 2
    ;;
esac
