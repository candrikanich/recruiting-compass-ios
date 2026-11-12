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
# gh pr view <N> ... → description "BODY-OF-PR-<N>"
echo "BODY-OF-PR-$3"
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
check() { # name, condition result
  if [ "$2" = 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; fails=$((fails + 1)); fi
}

out=$(sh "$SCRIPT" v1.0.3 2>&1); rc=$?
check "merge-commit PR description is fetched" "$(printf '%s' "$out" | grep -q 'BODY-OF-PR-579'; echo $?)"
check "squash PR description is fetched" "$(printf '%s' "$out" | grep -q 'BODY-OF-PR-583'; echo $?)"

# Clash: origin's v1.0.3 differs from the local one, so `git fetch --tags` is rejected.
git clone -q "$TMP/origin.git" "$TMP/other" 2>/dev/null
(cd "$TMP/other" && git tag -f -a v1.0.3 -m moved "$(git rev-parse HEAD)" >/dev/null && git push -q -f origin v1.0.3)
origin_tag_before=$(git -C "$TMP/origin.git" rev-parse v1.0.3)
out=$(sh "$SCRIPT" v1.0.3 2>&1); rc=$?
check "tag clash is reported with the git error" "$(printf '%s' "$out" | grep -qi 'clobber' ; echo $?)"
check "tag clash prints a --force hint" "$(printf '%s' "$out" | grep -q 'git fetch --tags --force origin'; echo $?)"
check "tag clash still lists PRs from local tags" "$(printf '%s' "$out" | grep -q 'BODY-OF-PR-579'; echo $?)"
check "tag clash never moves origin's tag" "$([ "$(git -C "$TMP/origin.git" rev-parse v1.0.3)" = "$origin_tag_before" ]; echo $?)"

# Unreachable origin with no usable range must exit non-zero and say why.
git remote set-url origin "$TMP/nope.git"
out=$(sh "$SCRIPT" v9.9.9 2>&1); rc=$?
check "bad base exits non-zero" "$([ "$rc" != 0 ]; echo $?)"
check "bad base prints a reason" "$([ -n "$out" ]; echo $?)"

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
