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
check "stale local tag still lists origin's range" "$(has "$stdout" BODY-OF-PR-579; echo $?)"
check "commits new on origin are listed" "$(has "$stdout" BODY-OF-PR-600; echo $?)"
check "local tag is left alone" "$([ "$(git rev-parse v1.0.3)" = "$local_tag_before" ]; echo $?)"
run local-only
fail_clean "tag that exists only locally"
check "local-only tag error says so" "$(has "$stderr" "only locally"; echo $?)"

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
