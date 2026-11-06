#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-generated-config.sh"
failures=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

expect() {
  local expected="$1" label="$2"; shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $label — expected exit $expected, got $actual"
    failures=$((failures + 1))
  fi
}

svc=TheRecruitingCompass/TheRecruitingCompass/Core/Services
expect 0 "unrelated paths" bash -c "printf 'a/Foo.swift\n' | '$SCRIPT' paths"
expect 1 "supabase config" bash -c "printf '$svc/SupabaseConfig.generated.swift\n' | '$SCRIPT' paths"
expect 1 "turnstile config" bash -c "printf '$svc/TurnstileConfig.generated.swift\n' | '$SCRIPT' paths"
expect 1 "posthog config" bash -c "printf '$svc/PostHogConfigEmbedded.swift\n' | '$SCRIPT' paths"

dest="$svc/SupabaseConfig.generated.swift"
mkdir -p "$tmp/stub/$svc" "$tmp/prod/$svc" "$tmp/comment/$svc" "$tmp/dup/$svc" "$tmp/dup/other/$svc" "$tmp/empty"
# Canonical committed stub, byte-for-byte.
cat > "$tmp/stub/$dest" <<'SWIFT'
import Foundation

/// Auto-generated at build time from Release.xcconfig. Do not edit manually.
/// This committed version is a placeholder stub — Xcode's "Generate Supabase config"
/// build phase overwrites it locally with real values from Release.xcconfig (gitignored).
enum SupabaseConfigEmbedded {
  static let urlString = "https://placeholder.supabase.co"
  static let anonKey = "placeholder-key"
  static let apiBaseURL = ""
}
SWIFT
cat > "$tmp/prod/$dest" <<'SWIFT'
enum SupabaseConfigEmbedded {
  static let urlString = "https://example-project.supabase.co"
  static let anonKey = "not-a-placeholder"
  static let apiBaseURL = "https://api.example.test"
}
SWIFT
# Placeholder strings kept in a comment while real values sit beside them.
{
  echo '// urlString = "https://placeholder.supabase.co" anonKey = "placeholder-key" apiBaseURL = ""'
  cat "$tmp/prod/$dest"
} > "$tmp/comment/$dest"
cp "$tmp/stub/$dest" "$tmp/dup/$dest"
cp "$tmp/stub/$dest" "$tmp/dup/other/$dest"
expect 0 "placeholder stub" "$SCRIPT" stub "$tmp/stub"
expect 1 "non-stub values" "$SCRIPT" stub "$tmp/prod"
expect 1 "placeholder in comment + real values" "$SCRIPT" stub "$tmp/comment"
expect 1 "duplicate matching files" "$SCRIPT" stub "$tmp/dup"
expect 1 "missing file" "$SCRIPT" stub "$tmp/empty"

[ "$failures" -eq 0 ] && echo "ok" || exit 1
