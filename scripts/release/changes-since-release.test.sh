#!/usr/bin/env bash
# Self-test for scripts/release/changes-since-release.sh. Builds a throwaway origin + clone with a merge-commit PR,
# a squash PR, and a local tag that clashes with origin's; `gh` is stubbed.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/changes-since-release.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

cat > "$TMP/bin/gh" <<'STUB'
#!/bin/sh
# gh pr view <N> ... → description "BODY-OF-PR-<N>" plus the args it was called with
echo "BODY-OF-PR-$3 (gh args: $*)"
STUB
chmod +x "$TMP/bin/gh"

PBX=TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj
git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/work" 2>/dev/null
cd "$TMP/work" || exit 1
git checkout -q -b main
mkdir -p "$(dirname "$PBX")"
echo 'MARKETING_VERSION = 1.0.4;' > "$PBX"
git add . && git commit -q -m "base"
git tag v1.0.3
git checkout -q -b feat
echo a > a && git add a && git commit -q -m "feat a"
git checkout -q main
git merge -q --no-ff feat -m "Merge pull request #579 from candrikanich/feat" -m "feat a"
echo b > b && git add b && git commit -q -m "squashed change (#583)"
git push -q origin main v1.0.3
git fetch -q origin

fails=0
has() { case $1 in *"$2"*) return 0 ;; esac; return 1; }
check() { # name, condition result
  if [ "$2" = 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; fails=$((fails + 1)); fi
}

out=$(sh "$SCRIPT" v1.0.3 2>&1); rc=$?
check "PR title is requested from gh" "$(has "$out" '--json title,'; echo $?)"
check "merge-commit PR description is fetched" "$(printf '%s' "$out" | grep -q 'BODY-OF-PR-579'; echo $?)"
check "squash PR description is fetched" "$(printf '%s' "$out" | grep -q 'BODY-OF-PR-583'; echo $?)"

# Clash on a tag that is NOT the range endpoint: v0.9.0 differs between local and origin. Origin also gains #600.
git tag v0.9.0
git clone -q "$TMP/origin.git" "$TMP/other" 2>/dev/null
(cd "$TMP/other" && git tag v0.9.0 "$(git rev-list --max-parents=0 HEAD)" && git push -q origin v0.9.0 \
  && echo c > c && git add c && git commit -q -m "new on origin (#600)" && git push -q origin HEAD:main)
local_tag_before=$(git rev-parse v0.9.0)
out=$(sh "$SCRIPT" v1.0.3 2>&1); rc=$?
check "tag clash is reported with the git error" "$(has "$out" 'clobber'; echo $?)"
check "tag clash prints a --force hint" "$(has "$out" 'git fetch --tags --force origin'; echo $?)"
check "tag clash still lists PRs from local tags" "$(has "$out" 'BODY-OF-PR-579'; echo $?)"
check "tag clash still lists commits new on origin" "$(has "$out" 'BODY-OF-PR-600'; echo $?)"
check "tag clash never moves the local tag" "$([ "$(git rev-parse v0.9.0)" = "$local_tag_before" ]; echo $?)"

# Clash plus a failing ref update in the same fetch: stale origin/main must not produce notes.
(cd "$TMP/other" && echo d > d && git add d && git commit -q -m "newer on origin (#601)" && git push -q origin HEAD:main)
touch .git/refs/remotes/origin/main.lock
stdout=$(sh "$SCRIPT" v1.0.3 2>"$TMP/stderr"); rc=$?
rm -f .git/refs/remotes/origin/main.lock
check "clash plus ref failure exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
check "clash plus ref failure prints nothing on stdout" "$([ -z "$stdout" ]; echo $?)"

# Bad base / bad end with a healthy origin: the specific reason, nothing on stdout.
stdout=$(sh "$SCRIPT" v9.9.9 2>"$TMP/stderr"); rc=$?
check "bad base exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
check "bad base names the revision" "$(grep -q "unknown revision 'v9.9.9'" "$TMP/stderr"; echo $?)"
check "bad base prints nothing on stdout" "$([ -z "$stdout" ]; echo $?)"
stdout=$(sh "$SCRIPT" v1.0.3 nope/branch 2>"$TMP/stderr"); rc=$?
check "bad end exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
check "bad end names the revision" "$(grep -q "unknown revision 'nope/branch'" "$TMP/stderr"; echo $?)"
check "bad end prints nothing on stdout" "$([ -z "$stdout" ]; echo $?)"

# Clash on the range endpoint itself: origin's v1.0.3 moves, so the local copy would give the wrong range.
(cd "$TMP/other" && git tag -f v1.0.3 HEAD >/dev/null && git push -q -f origin v1.0.3)
for args in "v1.0.3" "HEAD~1 v1.0.3"; do
  # shellcheck disable=SC2086
  stdout=$(sh "$SCRIPT" $args 2>"$TMP/stderr"); rc=$?
  check "endpoint clash ($args) exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
  check "endpoint clash ($args) prints nothing on stdout" "$([ -z "$stdout" ]; echo $?)"
  check "endpoint clash ($args) names the tag" "$(grep -q "local tag 'v1.0.3' differs" "$TMP/stderr"; echo $?)"
  check "endpoint clash ($args) gives the --force hint" "$(grep -q -- 'git fetch --tags --force origin' "$TMP/stderr"; echo $?)"
done

# Unreachable origin with a valid base: stale origin/main must not produce notes.
git remote set-url origin "$TMP/nope.git"
stdout=$(sh "$SCRIPT" v1.0.3 2>"$TMP/stderr"); rc=$?
check "unreachable origin exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
check "unreachable origin prints nothing on stdout" "$([ -z "$stdout" ]; echo $?)"
check "unreachable origin shows git's own error" "$(grep -q "does not appear to be a git repository" "$TMP/stderr"; echo $?)"
check "unreachable origin explains on stderr" "$(grep -q "failed, so origin/main may be stale" "$TMP/stderr"; echo $?)"
check "unreachable origin gets no --force hint" "$(grep -q -- '--force' "$TMP/stderr"; [ $? != 0 ]; echo $?)"

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
