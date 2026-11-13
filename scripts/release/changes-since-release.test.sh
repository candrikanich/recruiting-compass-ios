#!/usr/bin/env bash
# Self-test for scripts/release/changes-since-release.sh. Builds a throwaway origin + clone with a merge-commit PR,
# a squash PR, annotated and lightweight tags, and local tags that disagree with origin's; `gh` is stubbed.
# SH=dash scripts/release/changes-since-release.test.sh runs the script under another shell.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/changes-since-release.sh"
SH=${SH:-sh}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

cat > "$TMP/bin/gh" <<'STUB'
#!/bin/sh
# gh pr view <N> --json <fields> --template <T>: prints a description, the args, and a title only when asked for.
echo "BODY-OF-PR-$3 (gh args: $*)"
case "$*" in *'Title: {{.title}}'*) echo "Title: TITLE-OF-PR-$3" ;; esac
STUB
chmod +x "$TMP/bin/gh"

fails=0
check() { # name, exit status of the condition
  if [ "$2" = 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; fails=$((fails + 1)); fi
}
has() { case $1 in *"$2"*) return 0 ;; esac; return 1; }
run() { # args → sets stdout, stderr, rc
  stdout=$($SH "$SCRIPT" "$@" 2>"$TMP/stderr"); rc=$?
  stderr=$(cat "$TMP/stderr")
}
fail_clean() { # name: the last run must have exited non-zero with nothing on stdout
  check "$1 exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
  check "$1 prints nothing on stdout" "$([ -z "$stdout" ]; echo $?)"
}

# Upload-pack wrapper: counts calls; WRAP/fail_from makes call N onward fail, WRAP/warn adds a stderr line.
WRAP="$TMP/wrap"; mkdir -p "$WRAP"
cat > "$WRAP/up" <<'STUB'
#!/bin/sh
d=$(dirname "$0")
n=$(( $(cat "$d/count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$d/count"
[ -f "$d/warn" ] && echo "warning: redirecting to https://example.invalid/repo.git/" >&2
if [ -f "$d/fail_from" ] && [ "$n" -ge "$(cat "$d/fail_from")" ]; then
  echo "wrapper: simulated upload-pack failure" >&2; exit 128
fi
exec "$(git --exec-path)/git-upload-pack" "$@"
STUB
chmod +x "$WRAP/up"
wrap_on() { git config remote.origin.uploadpack "$WRAP/up"; rm -f "$WRAP/count" "$WRAP/warn" "$WRAP/fail_from"; }
wrap_off() { git config --unset remote.origin.uploadpack; rm -f "$WRAP/count" "$WRAP/warn" "$WRAP/fail_from"; }

PBX=TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj
git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/work" 2>/dev/null
cd "$TMP/work" || exit 1
git checkout -q -b main
mkdir -p "$(dirname "$PBX")"
echo 'MARKETING_VERSION = 1.0.4;' > "$PBX"
git add . && git commit -q -m "root"
git tag -a v1.0.2 -m "annotated release"
echo base > base && git add base && git commit -q -m "base"
git tag v1.0.3
git checkout -q -b feat
echo a > a && git add a && git commit -q -m "feat a"
git checkout -q main
git merge -q --no-ff feat -m "Merge pull request #579 from candrikanich/feat" -m "feat a"
echo b > b && git add b && git commit -q -m "squashed change (#583)"
git push -q origin main v1.0.2 v1.0.3
git fetch -q origin
ROOT=$(git rev-parse v1.0.2^{commit})
TAG_OBJECT=$(git rev-parse v1.0.2)

run v1.0.3
healthy=$stdout
check "healthy run exits zero" "$([ "$rc" = 0 ]; echo $?)"
check "merge-commit PR description is fetched" "$(has "$stdout" BODY-OF-PR-579; echo $?)"
check "squash PR description is fetched" "$(has "$stdout" BODY-OF-PR-583; echo $?)"
check "PR title is requested from gh" "$(has "$stdout" '--json title,'; echo $?)"
check "PR title line is rendered" "$(has "$stdout" 'Title: TITLE-OF-PR-579'; echo $?)"

# Every spelling of one tag is the same endpoint.
for spelling in tags/v1.0.3 refs/tags/v1.0.3 'v1.0.3^0'; do
  run "$spelling"
  check "spelling $spelling matches v1.0.3" "$([ "$stdout" = "$healthy" ]; echo $?)"
done

# Annotated tags resolve to their commit, not the tag object.
run v1.0.2
check "annotated tag exits zero" "$([ "$rc" = 0 ]; echo $?)"
check "annotated tag range starts at the tagged commit" \
  "$(has "$stdout" "($(git rev-parse --short "$ROOT"))"; echo $?)"
check "annotated tag object sha is not used" "$(has "$stdout" "($(git rev-parse --short "$TAG_OBJECT"))"; [ $? != 0 ]; echo $?)"

# Local tags are never read: v1.0.3 is moved to the tip locally, origin's still says "base".
git tag -f v1.0.3 main >/dev/null
local_tag_before=$(git rev-parse v1.0.3)
git tag local-only main
(git clone -q "$TMP/origin.git" "$TMP/other" 2>/dev/null && cd "$TMP/other" \
  && echo c > c && git add c && git commit -q -m "new on origin (#600)" && git push -q origin HEAD:main)
run v1.0.3
check "stale local tag exits zero" "$([ "$rc" = 0 ]; echo $?)"
stale=$stdout
check "stale local tag still lists origin's range" "$(has "$stdout" BODY-OF-PR-579; echo $?)"
check "commits new on origin are listed" "$(has "$stdout" BODY-OF-PR-600; echo $?)"
check "local tag is left alone" "$([ "$(git rev-parse v1.0.3)" = "$local_tag_before" ]; echo $?)"
run local-only
fail_clean "tag that exists only locally"
check "local-only tag error says so" "$(has "$stderr" "only locally"; echo $?)"

# Spellings that read the stale local v1.0.3 must not (healthy run above was made before the tag moved).
for spelling in 'v1.0.3^{commit}' 'v1.0.3~0' tags/v1.0.3 refs/tags/v1.0.3 'v1.0.3^0'; do
  run "$spelling"
  check "stale local tag: spelling $spelling matches v1.0.3" "$([ "$stdout" = "$stale" ]; echo $?)"
done
for spelling in 'v1.0.3~1' 'v1.0.3^1' 'v1.0.3~2' 'v1.0.3..main' main hotfix/1.0.2; do
  run "$spelling"
  fail_clean "endpoint $spelling"
  check "endpoint $spelling is rejected as an endpoint" "$(has "$stderr" 'endpoint must be a release tag'; echo $?)"
done
run v1.0.3 origin/main
check "explicit origin/main end is the default end" "$([ "$rc" = 0 ] && [ "$stdout" = "$stale" ]; echo $?)"
run "$(git rev-parse --short=8 v1.0.2)"
check "abbreviated commit SHA is accepted" "$([ "$rc" = 0 ]; echo $?)"
run "$(git rev-parse v1.0.2)" "$(git rev-parse v1.0.3)"
check "full commit SHAs are accepted" "$([ "$rc" = 0 ]; echo $?)"

# A new tag on origin with a stale lock for the same tag locally used to fail the tag fetch and leave a stale range.
(cd "$TMP/other" && echo d > d && git add d && git commit -q -m "release commit (#601)" \
  && git tag v1.0.4 && git push -q origin HEAD:main v1.0.4)
RELEASE=$(git -C "$TMP/other" rev-parse HEAD)
touch .git/refs/tags/v1.0.4.lock
run
check "default base with a locked new tag exits zero" "$([ "$rc" = 0 ]; echo $?)"
check "default base is origin's newest tag, not a stale one" \
  "$(has "$stdout" "Changes since v1.0.4"; echo $?)"
check "default base resolves to the new tag's commit" \
  "$(has "$stdout" "($(git rev-parse --short "$RELEASE"))  →"; echo $?)"
rm -f .git/refs/tags/v1.0.4.lock

# Version order, not lexical: v1.0.10 is newer than v1.0.9.
(cd "$TMP/other" && git tag v1.0.9 && git tag v1.0.10 && git push -q origin v1.0.9 v1.0.10)
run
check "default base sorts versions numerically" "$(has "$stdout" "Changes since v1.0.10"; echo $?)"

# ls-remote output on stderr is not tag data.
wrap_on; touch "$WRAP/warn"
run
check "default base ignores remote stderr noise" "$(has "$stdout" "Changes since v1.0.10"; echo $?)"
wrap_off

# A transient failure after the branch fetch succeeded: call 1 is the fetch, later calls fail.
for args in "v1.0.3" ""; do
  wrap_on; echo 2 > "$WRAP/fail_from"
  # shellcheck disable=SC2086
  run $args
  fail_clean "ls-remote failure (args: '$args')"
  check "ls-remote failure (args: '$args') shows git's error" "$(has "$stderr" 'simulated upload-pack failure'; echo $?)"
  check "ls-remote failure (args: '$args') says what failed" "$(has "$stderr" "git ls-remote --tags origin"; echo $?)"
  wrap_off
done

# A tag whose commit is on no branch: fetched from origin on demand, without writing a local tag.
(cd "$TMP/other" && git checkout -q --detach && echo h > h && git add h && git commit -q -m "hotfix (#700)" \
  && git tag v1.0.3-hotfix && git push -q origin v1.0.3-hotfix)
# Calls: 1 branch fetch, 2-3 ls-remote (base, end), 4 the commit fetch.
wrap_on; echo 4 > "$WRAP/fail_from"
run v1.0.3 v1.0.3-hotfix
wrap_off
fail_clean "failed commit fetch"
check "failed commit fetch names the tag" "$(has "$stderr" "could not fetch tag 'v1.0.3-hotfix'"; echo $?)"
check "failed commit fetch shows git's error" "$(has "$stderr" 'simulated upload-pack failure'; echo $?)"
run v1.0.3 v1.0.3-hotfix
check "tag on a branchless commit exits zero" "$([ "$rc" = 0 ]; echo $?)"
check "tag on a branchless commit lists its PR" "$(has "$stdout" BODY-OF-PR-700; echo $?)"
check "fetching the commit writes no local tag" "$([ -z "$(git tag --list v1.0.3-hotfix)" ]; echo $?)"

# A ref that fails to update stops the run, even with a clashing tag in the same fetch.
git tag -f v0.9.0 main >/dev/null
(cd "$TMP/other" && git tag v0.9.0 "$(git rev-list --max-parents=0 HEAD)" && git push -q origin v0.9.0 \
  && echo e > e && git add e && git commit -q -m "newer (#602)" && git push -q origin HEAD:main)
touch .git/refs/remotes/origin/main.lock
run v1.0.3
fail_clean "ref lock"
check "ref lock shows git's error" "$(has "$stderr" "cannot lock ref"; echo $?)"
rm -f .git/refs/remotes/origin/main.lock

# Bad base / bad end with a healthy origin: the specific reason, nothing on stdout.
run v9.9.9
fail_clean "bad base"
check "bad base names the revision" "$(has "$stderr" "unknown revision 'v9.9.9'"; echo $?)"
run v1.0.3 nope/branch
fail_clean "bad end"
check "bad end names the revision" "$(has "$stderr" "unknown revision 'nope/branch'"; echo $?)"

# Unreachable origin with a valid base: stale origin/main must not produce notes.
git remote set-url origin "$TMP/nope.git"
run v1.0.3
fail_clean "unreachable origin"
check "unreachable origin shows git's own error" "$(has "$stderr" "does not appear to be a git repository"; echo $?)"
check "unreachable origin explains on stderr" "$(has "$stderr" "may be stale"; echo $?)"

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
