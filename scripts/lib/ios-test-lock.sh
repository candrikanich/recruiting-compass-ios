# Machine-wide lock for iOS simulator test runs. Source it (bash or zsh), then:
#
#   ios_test_lock_acquire <wait-seconds> <label> || exit $?   # 0 = held, 75 = timed out
#   ios_test_lock_release                                      # idempotent; call it from an EXIT trap
#
# Every agent, worktree, CI clone and the nightly share this one lock file, because two runs
# cold-booting simulators side by side exhaust this Mac's memory until both stall.
# The lock is held by a small lockf child that lets go within a second of the acquiring script's
# process exiting, so a run killed with -9 can't leave it stuck. scripts/sim_sweep.py reads the
# owner file to report who holds it.

IOS_TEST_LOCK_DIR="${IOS_TEST_LOCK_DIR:-$HOME/Library/Application Support/recruiting-compass}"
IOS_TEST_LOCK="$IOS_TEST_LOCK_DIR/ios-test.lock"
IOS_TEST_LOCK_OWNER="$IOS_TEST_LOCK.owner"
_ios_test_lock_token=""
_ios_test_lock_holder=""

ios_test_lock_owner() {
  if [ -s "$IOS_TEST_LOCK_OWNER" ]; then
    tr '\n' ' ' < "$IOS_TEST_LOCK_OWNER"
  else
    echo "unknown (no owner file)"
  fi
}

ios_test_lock_acquire() {
  local wait_seconds="$1" label="$2" ticks=0
  mkdir -p "$IOS_TEST_LOCK_DIR"
  _ios_test_lock_token="$(mktemp -d "${TMPDIR:-/tmp}/ios-test-lock.XXXXXX")"
  lockf -k -t "$wait_seconds" "$IOS_TEST_LOCK" /bin/sh -c '
    : > "$1/held"
    while kill -0 "$2" 2>/dev/null && [ ! -e "$1/release" ]; do sleep 1; done
  ' ios-test-lock "$_ios_test_lock_token" "$$" 2>/dev/null &
  _ios_test_lock_holder=$!
  while [ ! -e "$_ios_test_lock_token/held" ]; do
    if ! kill -0 "$_ios_test_lock_holder" 2>/dev/null && [ ! -e "$_ios_test_lock_token/held" ]; then
      echo "ios-test-lock: Timed out after ${wait_seconds}s waiting for the iOS test lock, held by: $(ios_test_lock_owner)" >&2
      rm -rf "$_ios_test_lock_token"
      _ios_test_lock_token=""
      _ios_test_lock_holder=""
      return 75
    fi
    # First notice after a second (a free lock is taken well before that), then every 5 minutes.
    if [ $((ticks % 1500)) -eq 5 ]; then
      echo "ios-test-lock: waiting for the iOS test lock, held by: $(ios_test_lock_owner)" >&2
    fi
    sleep 0.2
    ticks=$((ticks + 1))
  done
  printf 'pid=%s\nlabel=%s\ndir=%s\nbranch=%s\nstarted=%s\n' "$$" "$label" "$PWD" \
    "$(git branch --show-current 2>/dev/null)" "$(date '+%Y-%m-%d %H:%M:%S')" > "$IOS_TEST_LOCK_OWNER"
}

ios_test_lock_release() {
  [ -n "$_ios_test_lock_token" ] || return 0
  # Remove the owner file before letting go, so it never deletes the next holder's.
  if [ "$(sed -n 's/^pid=//p' "$IOS_TEST_LOCK_OWNER" 2>/dev/null)" = "$$" ]; then
    rm -f "$IOS_TEST_LOCK_OWNER"
  fi
  : > "$_ios_test_lock_token/release"
  wait "$_ios_test_lock_holder" 2>/dev/null || true
  rm -rf "$_ios_test_lock_token"
  _ios_test_lock_token=""
  _ios_test_lock_holder=""
}
