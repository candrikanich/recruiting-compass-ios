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

mkdir -p "$tmp/stub/$svc" "$tmp/prod/$svc"
cat > "$tmp/stub/$svc/SupabaseConfig.generated.swift" <<'SWIFT'
enum SupabaseConfigEmbedded {
  static let urlString = "https://placeholder.supabase.co"
  static let anonKey = "placeholder-key"
  static let apiBaseURL = ""
}
SWIFT
cat > "$tmp/prod/$svc/SupabaseConfig.generated.swift" <<'SWIFT'
enum SupabaseConfigEmbedded {
  static let urlString = "https://example-project.supabase.co"
  static let anonKey = "not-a-placeholder"
  static let apiBaseURL = "https://api.example.test"
}
SWIFT
expect 0 "placeholder stub" "$SCRIPT" stub "$tmp/stub"
expect 1 "non-stub values" "$SCRIPT" stub "$tmp/prod"
mkdir "$tmp/empty"
expect 1 "missing file" "$SCRIPT" stub "$tmp/empty"

[ "$failures" -eq 0 ] && echo "ok" || exit 1
