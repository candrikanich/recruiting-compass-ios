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
# (ok|fail), plus env mode (env-ok|env-empty), plus optional free disk in KB,
# plus any extra nightly-local.sh arguments. NIGHTLY_E2E_WORKTREE_REPO passes
# through so worktree pruning can target a scratch repo.
run_nightly() {
  local starts=$1 env_mode=$2 free_kb=${3:-104857600} tmp
  shift $(($# < 3 ? $# : 3))
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
  printf '#!/bin/sh\necho "Filesystem 1024-blocks Used Available Capacity Mounted on"\necho "/dev/stub 500000000 1 %s 99%% /"\n' "$free_kb" > "$tmp/bin/df"
  chmod +x "$tmp/bin/docker" "$tmp/bin/npm" "$tmp/bin/df"
  mkdir -p "$tmp/docker-logs/vm" "$tmp/docker-logs/host"
  echo "stub-engine-api-line" > "$tmp/docker-logs/vm/init.log"
  echo "stub-backend-line" > "$tmp/docker-logs/host/com.docker.backend.log"

  PATH="$tmp/bin:$PATH" \
    NIGHTLY_E2E_WEB_DIR="$tmp/web" \
    NIGHTLY_E2E_STATE_DIR="$tmp/state" \
    NIGHTLY_E2E_LOG_DIR="$tmp/logs" \
    NIGHTLY_E2E_DOCKER_LOG_DIR="$tmp/docker-logs" \
    NIGHTLY_E2E_WORKTREE_REPO="${NIGHTLY_E2E_WORKTREE_REPO:-}" \
    bash "$SCRIPT" --no-update "$@" >/dev/null 2>&1 || true
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

out="$(run_nightly ok env-ok 5242880)"
expect "low disk" "$out" "FAILED: low disk space: 5 GB free, need 20 GB"
expect_not "low disk" "$out" "Local Supabase at"

out="$(run_nightly ok env-ok)"
expect "enough disk" "$out" "Disk: 100 GB free"
expect_not "enough disk" "$out" "low disk space"
expect_not "no prune by default" "$out" "merged worktree"

# A repo whose linked worktrees cover every pruning rule. All but merged-fresh
# get an index older than the 24h idle window.
make_worktree_repo() {
  local repo=$1 w
  git init -q -b main "$repo"
  mkdir -p "$repo/Core"
  echo a > "$repo/Core/SupabaseConfig.generated.swift"
  echo a > "$repo/Core/PostHogConfigEmbedded.swift"
  echo a > "$repo/Core/Feature.swift"
  git -C "$repo" add -A
  git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init
  git -C "$repo" update-ref refs/remotes/origin/main HEAD
  for w in merged-clean merged-generated merged-edited merged-untracked merged-lookalike merged-fresh unmerged; do
    git -C "$repo" worktree add -q --detach "$repo/.claude/worktrees/$w" HEAD
  done
  echo b > "$repo/.claude/worktrees/merged-generated/Core/SupabaseConfig.generated.swift"
  echo b > "$repo/.claude/worktrees/merged-generated/Core/PostHogConfigEmbedded.swift"
  echo b > "$repo/.claude/worktrees/merged-edited/Core/Feature.swift"
  echo b > "$repo/.claude/worktrees/merged-untracked/Core/NewFeature.swift"
  echo b > "$repo/.claude/worktrees/merged-lookalike/Core/MySupabaseConfig.generated.swift"
  git -C "$repo/.claude/worktrees/unmerged" -c user.name=t -c user.email=t@t \
    commit -q --allow-empty -m wip
  for w in merged-clean merged-generated merged-edited merged-untracked merged-lookalike unmerged; do
    git -C "$repo/.claude/worktrees/$w" status --porcelain >/dev/null
    touch -t 202001010000 "$(git -C "$repo/.claude/worktrees/$w" rev-parse --path-format=absolute --git-path index)"
  done
}

prune_repo="$(mktemp -d)/repo"
make_worktree_repo "$prune_repo"
out="$(NIGHTLY_E2E_WORKTREE_REPO="$prune_repo" run_nightly ok env-ok 5242880 --prune-worktrees)"
expect "prune" "$out" "Removed merged worktree .*/merged-clean"
expect "prune" "$out" "Removed merged worktree .*/merged-generated"
expect "prune" "$out" "Kept worktree .*/merged-edited: uncommitted changes"
expect "prune" "$out" "Kept worktree .*/merged-untracked: uncommitted changes"
expect "prune" "$out" "Kept worktree .*/merged-lookalike: uncommitted changes"
expect "prune" "$out" "Kept worktree .*/unmerged: not in origin/main"
expect "prune" "$out" "Kept worktree .*/merged-fresh: used in the last 24h"
expect "prune runs before disk check" "$(grep -E 'Removed merged worktree|Disk:' <<<"$out" | head -1)" "Removed merged worktree"
for w in merged-clean merged-generated; do
  [ ! -e "$prune_repo/.claude/worktrees/$w" ] || { echo "FAIL [prune]: $w still exists"; FAILURES=$((FAILURES + 1)); }
done
for w in merged-edited merged-untracked merged-lookalike merged-fresh unmerged; do
  [ -d "$prune_repo/.claude/worktrees/$w" ] || { echo "FAIL [prune]: $w was removed"; FAILURES=$((FAILURES + 1)); }
done
[ -d "$prune_repo/Core" ] || { echo "FAIL [prune]: main worktree was removed"; FAILURES=$((FAILURES + 1)); }
rm -rf "$(dirname "$prune_repo")"

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES expectation(s) failed"
  exit 1
fi
echo "all nightly expectations passed"
