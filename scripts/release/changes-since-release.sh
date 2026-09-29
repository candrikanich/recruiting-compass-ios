#!/bin/sh
# Lists everything merged to main since the last release tag, as raw material for release notes.
#
#   scripts/release/changes-since-release.sh            # since the newest v* tag
#   scripts/release/changes-since-release.sh v1.0.1     # since a specific tag/ref
#
# Output: markdown with the version being prepared, then one section per commit on main
# (squash-merged PRs include the PR title, labels and description; direct commits include
# the commit body). Used by the whats-new skill (.claude/skills/whats-new).

set -eu

REPO_ROOT=$(git rev-parse --show-toplevel)
PBXPROJ="$REPO_ROOT/TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj"

git fetch --quiet --tags origin main

BASE=${1:-$(git tag --list 'v*' --sort=-version:refname | head -n 1)}
if [ -z "$BASE" ]; then
  echo "error: no v* release tag found; pass a base ref explicitly." >&2
  exit 1
fi

VERSION=$(grep -o 'MARKETING_VERSION = [0-9.]*;' "$PBXPROJ" | sort -u | sed 's/MARKETING_VERSION = //; s/;//')

echo "# Changes on main since $BASE"
echo
echo "- Version being prepared (MARKETING_VERSION): $VERSION"
echo "- Base: $BASE ($(git rev-parse --short "$BASE"))  →  origin/main ($(git rev-parse --short origin/main))"
echo

COMMITS=$(git log --first-parent --reverse --format='%H' "$BASE..origin/main")
if [ -z "$COMMITS" ]; then
  echo "_No commits since $BASE._"
  exit 0
fi

for sha in $COMMITS; do
  subject=$(git log -1 --format='%s' "$sha")
  pr=$(printf '%s' "$subject" | sed -n 's/.*(#\([0-9][0-9]*\))$/\1/p')
  echo "## COMMIT: $subject"
  echo
  # Bodies are quoted so their own markdown headings don't read as new commits.
  {
    if [ -n "$pr" ] && command -v gh >/dev/null 2>&1; then
      gh pr view "$pr" --json labels,body \
        --template '{{if .labels}}Labels: {{range $i, $l := .labels}}{{if $i}}, {{end}}{{$l.name}}{{end}}{{"\n\n"}}{{end}}{{.body}}{{"\n"}}' \
        2>/dev/null | sed -n '1,60p' || git log -1 --format='%b' "$sha"
    else
      git log -1 --format='%b' "$sha"
    fi
  } | sed 's/^/> /'
  echo
done
