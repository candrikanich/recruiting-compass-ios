#!/usr/bin/env bash
# Exercises nightly-local.sh's local Supabase start against a stubbed
# local-supabase.sh, docker and npm, so no Docker, network or simulator is
# touched. The run stops at seed (stub npm fails), which is past start_stack.
#
#   scripts/e2e/test-nightly-start-stack.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nightly-local.sh"
FAILURES=0

# $1 = stub behaviour: comma-separated per-attempt results for `start`
# (ok|fail), plus env mode (env-ok|env-empty).
run_nightly() {
  local starts=$1 env_mode=$2 tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/web/scripts/e2e" "$tmp/bin" "$tmp/state" "$tmp/logs"
  git -C "$tmp/web" init -q
  git -C "$tmp/web" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

  cat > "$tmp/web/scripts/e2e/local-supabase.sh" <<EOF
#!/usr/bin/env bash
case "\$1" in
  start)
    n=\$(( \$(cat "$tmp/starts" 2>/dev/null || echo 0) + 1 ))
    echo "\$n" > "$tmp/starts"
    result=\$(echo "$starts" | cut -d, -f"\$n")
    [ "\$result" = ok ] && exit 0
    exit 1 ;;
  env)
    [ "$env_mode" = env-ok ] || exit 0
    printf '%s\n' TEST_SUPABASE_URL=http://stub NUXT_PUBLIC_SUPABASE_ANON_KEY=anon SUPABASE_SERVICE_ROLE_KEY=service ;;
  stop) exit 0 ;;
esac
EOF
  chmod +x "$tmp/web/scripts/e2e/local-supabase.sh"
  printf '#!/bin/sh\necho "stub-docker $*"\n' > "$tmp/bin/docker"
  printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/npm"
  chmod +x "$tmp/bin/docker" "$tmp/bin/npm"
  mkdir -p "$tmp/docker-logs/vm" "$tmp/docker-logs/host"
  echo "stub-engine-api-line" > "$tmp/docker-logs/vm/init.log"
  echo "stub-backend-line" > "$tmp/docker-logs/host/com.docker.backend.log"

  PATH="$tmp/bin:$PATH" \
    NIGHTLY_E2E_WEB_DIR="$tmp/web" \
    NIGHTLY_E2E_STATE_DIR="$tmp/state" \
    NIGHTLY_E2E_LOG_DIR="$tmp/logs" \
    NIGHTLY_E2E_DOCKER_LOG_DIR="$tmp/docker-logs" \
    bash "$SCRIPT" --no-update >/dev/null 2>&1 || true
  cat "$tmp"/logs/ios-nightly-e2e-*.log
  rm -rf "$tmp"
}

expect() {
  local name=$1 output=$2 pattern=$3
  if ! grep -qE "$pattern" <<<"$output"; then
    echo "FAIL [$name]: expected /$pattern/ in:"
    sed 's/^/    /' <<<"$output"
    FAILURES=$((FAILURES + 1))
  fi
}

expect_not() {
  local name=$1 output=$2 pattern=$3
  if grep -qE "$pattern" <<<"$output"; then
    echo "FAIL [$name]: did not expect /$pattern/ in:"
    sed 's/^/    /' <<<"$output"
    FAILURES=$((FAILURES + 1))
  fi
}

out="$(run_nightly fail,ok env-ok)"
expect "retry recovers" "$out" "supabase start exited 1 on attempt 1 of 2"
expect "retry recovers" "$out" "Local Supabase at http://stub"
expect_not "retry recovers" "$out" "stack did not start"
expect "diagnostics" "$out" "Saved stack diagnostics from attempt 1 to .*-stack-attempt-1\.log"
expect_not "diagnostics" "$out" "stack-attempt-2\.log"
expect "diagnostics" "$out" "stub-docker ps -a"
expect "diagnostics" "$out" "stub-docker inspect supabase_db_rc-ios-e2e"
expect "diagnostics" "$out" "stub-docker logs .*supabase_db_rc-ios-e2e"
expect "diagnostics" "$out" "stub-engine-api-line"
expect "diagnostics" "$out" "stub-backend-line"

out="$(run_nightly ok,ok env-empty)"
expect "empty env" "$out" "env returned no TEST_SUPABASE_URL NUXT_PUBLIC_SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY on attempt 2 of 2"
expect "empty env" "$out" "FAILED: local Supabase stack did not start"

out="$(run_nightly fail,fail env-ok)"
expect "both fail" "$out" "supabase start exited 1 on attempt 2 of 2"
expect "both fail" "$out" "FAILED: local Supabase stack did not start"

out="$(run_nightly ok env-ok)"
expect "first try" "$out" "Local Supabase at http://stub"
expect_not "first try" "$out" "attempt 1 of 2"
expect_not "first try" "$out" "stack diagnostics"

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES expectation(s) failed"
  exit 1
fi
echo "all start_stack expectations passed"
