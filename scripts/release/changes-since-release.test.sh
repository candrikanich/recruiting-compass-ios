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

# git shim: with $TMP/noop-tag-fetch present, the on-demand tag fetch "succeeds" without fetching anything.
cat > "$TMP/bin/git" <<STUB
#!/bin/sh
if [ -f "$TMP/noop-tag-fetch" ]; then
  case "\$*" in *"fetch --no-tags origin +refs/tags/"*) exit 0 ;; esac
fi
exec $(command -v git) "\$@"
STUB
chmod +x "$TMP/bin/git"

PBX=TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj
git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/work" 2>/dev/null
cd "$TMP/work" || exit 1
git checkout -q -b main; git config advice.objectNameWarning false
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

# refs/tags/ is the only accepted prefix.
run refs/tags/v1.0.3
check "refs/tags/ prefix matches v1.0.3" "$([ "$stdout" = "$healthy" ]; echo $?)"

# Annotated tags resolve to their commit, not the tag object.
run v1.0.2
check "annotated tag exits zero" "$([ "$rc" = 0 ]; echo $?)"
check "annotated tag range starts at the tagged commit" \
  "$(has "$stdout" "($(git rev-parse --short "$ROOT" 2>/dev/null))"; echo $?)"
check "annotated tag object sha is not used" "$(has "$stdout" "($(git rev-parse --short "$TAG_OBJECT"))"; [ $? != 0 ]; echo $?)"

# Local tags are never read: v1.0.3 is moved to the tip locally, origin's still says "base".
git tag -f v1.0.3 main >/dev/null
local_tag_before=$(git rev-parse v1.0.3)
git tag v7.7.7 main
(git clone -q "$TMP/origin.git" "$TMP/other" 2>/dev/null && cd "$TMP/other" \
  && echo c > c && git add c && git commit -q -m "new on origin (#600)" && git push -q origin HEAD:main)
run v1.0.3
check "stale local tag exits zero" "$([ "$rc" = 0 ]; echo $?)"
stale=$stdout
check "stale local tag still lists origin's range" "$(has "$stdout" BODY-OF-PR-579; echo $?)"
check "commits new on origin are listed" "$(has "$stdout" BODY-OF-PR-600; echo $?)"
check "local tag is left alone" "$([ "$(git rev-parse v1.0.3)" = "$local_tag_before" ]; echo $?)"
run v7.7.7
fail_clean "tag that exists only locally"
check "local-only tag error says so" "$(has "$stderr" "only locally"; echo $?)"

# Every other spelling is rejected with the one message, even with a stale local v1.0.3 and an annotated v1.0.2.
git branch cafe main; git branch bad main

BAD='endpoint must be a release tag (vX.Y.Z) or a full commit SHA'
for spelling in tags/v1.0.3 'v1.0.3^0' 'v1.0.3^{commit}' 'v1.0.3~0' 'v1.0.3~1' 'v1.0.3^1' 'v1.0.3^{}' 'v1.0.2^{}' 'v1.0.2^0' \
  'v1.0.3..main' main hotfix/1.0.2 cafe bad "$(git rev-parse --short=8 v1.0.2^{commit})" "$(git rev-parse v1.0.2^{commit} | tr a-f A-F)" \
  "${ROOT}0" "$(printf 'v1.0.3\nx')" v1 v1.0 v1.0.3-rc.1 V1.0.3 ' v1.0.3'; do
  run "$spelling"
  fail_clean "endpoint '$spelling'"
  check "endpoint '$spelling' gets the endpoint message" "$(has "$stderr" "$BAD"; echo $?)"
  run v1.0.3 "$spelling"
  fail_clean "end '$spelling'"
  check "end '$spelling' gets the endpoint message" "$(has "$stderr" "$BAD"; echo $?)"
done
run ''
fail_clean "empty endpoint"
git branch -q -D cafe bad

# Full SHAs are objects: even when a tag on origin or a branch has the same name; blobs and unknown SHAs are not.
run "$(git rev-parse v1.0.2^{commit})" "$(git rev-parse v1.0.3)"
check "full commit SHAs are accepted" "$([ "$rc" = 0 ]; echo $?)"
SHA_TAG_COMMIT=$(git rev-parse v1.0.3)
(cd "$TMP/other" && git tag -f "$ROOT" "$(git rev-parse HEAD)" >/dev/null && git push -q origin "refs/tags/$ROOT")
git update-ref "refs/heads/$ROOT" main
run "$ROOT"
check "SHA that is also a tag on origin and a branch is the object" \
  "$([ "$rc" = 0 ] && has "$stdout" "($(git rev-parse --short "$ROOT" 2>/dev/null))"; echo $?)"
run "$ROOT" "$ROOT"
check "SHA as both ends is an empty range" "$([ "$rc" = 0 ] && has "$stdout" 'No commits since'; echo $?)"
git update-ref -d "refs/heads/$ROOT"
(cd "$TMP/other" && git push -q origin ":refs/tags/$ROOT")
run "$(git rev-parse main:base)"
fail_clean "blob SHA"
check "blob SHA gets the endpoint message" "$(has "$stderr" "$BAD"; echo $?)"
run deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
fail_clean "unknown full SHA"
check "unknown full SHA gets the endpoint message" "$(has "$stderr" "$BAD"; echo $?)"

# origin/main as the end: a local tag or branch of that name changes nothing.
git tag origin/main "$ROOT" 2>/dev/null
git update-ref refs/heads/origin/main "$ROOT" 2>/dev/null
run v1.0.3
omitted=$stdout
run v1.0.3 origin/main
check "explicit origin/main end equals the omitted end" "$([ "$rc" = 0 ] && [ "$stdout" = "$omitted" ]; echo $?)"
check "omitted end is the remote-tracking origin/main" "$(has "$omitted" "→  origin/main ($(git rev-parse --short refs/remotes/origin/main))"; echo $?)"
git tag -d origin/main >/dev/null 2>&1; git update-ref -d refs/heads/origin/main 2>/dev/null

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
  && git tag v1.0.11 && git push -q origin v1.0.11)
# Calls: 1 branch fetch, 2-3 ls-remote (base, end), 4 the commit fetch.
wrap_on; echo 4 > "$WRAP/fail_from"
run v1.0.3 v1.0.11
wrap_off
fail_clean "failed commit fetch"
check "failed commit fetch names the tag" "$(has "$stderr" "could not fetch tag 'v1.0.11'"; echo $?)"
check "failed commit fetch shows git's error" "$(has "$stderr" 'simulated upload-pack failure'; echo $?)"
run v1.0.3 v1.0.11
check "tag on a branchless commit exits zero" "$([ "$rc" = 0 ]; echo $?)"
check "tag on a branchless commit lists its PR" "$(has "$stdout" BODY-OF-PR-700; echo $?)"
check "fetching the commit writes no local tag" "$([ -z "$(git tag --list v1.0.11)" ]; echo $?)"

# The tag fetch reports success but the commit is still missing: stop before any output.
(cd "$TMP/other" && git checkout -q --detach && echo i > i && git add i && git commit -q -m "hotfix 2 (#701)" \
  && git tag v1.0.12 && git push -q origin v1.0.12)
touch "$TMP/noop-tag-fetch"
run v1.0.3 v1.0.12
rm -f "$TMP/noop-tag-fetch"
fail_clean "tag fetch that fetches nothing"
check "tag fetch that fetches nothing says so" "$(has "$stderr" 'was not fetched'; echo $?)"

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
run v1.0.3 v9.9.8
fail_clean "bad end"
check "bad end names the revision" "$(has "$stderr" "unknown revision 'v9.9.8'"; echo $?)"

# Unreachable origin with a valid base: stale origin/main must not produce notes.
git remote set-url origin "$TMP/nope.git"
run v1.0.3
fail_clean "unreachable origin"
check "unreachable origin shows git's own error" "$(has "$stderr" "does not appear to be a git repository"; echo $?)"
check "unreachable origin explains on stderr" "$(has "$stderr" "may be stale"; echo $?)"

# No release tag on origin at all: the default base has nothing to start from.
git init -q --bare -b main "$TMP/empty.git"
git clone -q "$TMP/empty.git" "$TMP/emptywork" 2>/dev/null
(cd "$TMP/emptywork" && git checkout -q -b main && echo x > x && git add x && git commit -q -m x && git push -q origin main)
cd "$TMP/emptywork" && run
fail_clean "origin without release tags"
check "origin without release tags says so" "$(has "$stderr" 'no v* release tag found on origin'; echo $?)"

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
