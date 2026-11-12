#!/bin/sh
# Lists everything merged since the last release tag, as raw material for release notes.
#
#   scripts/release/changes-since-release.sh                          # newest v* tag → origin/main
#   scripts/release/changes-since-release.sh v1.0.1                   # a specific tag/ref → origin/main
#   scripts/release/changes-since-release.sh v1.0.1 hotfix/1.0.2      # hotfix: tag → the branch being released
#
# The end ref must be whatever the release build is made from — for a hotfix that's the hotfix branch,
# not main, or the notes would advertise unreleased work sitting on main.
#
# Output: markdown with the version being prepared (MARKETING_VERSION at the end ref), then one section
# per first-parent commit (PRs (squash or merge commit) include labels + full description; direct commits, or PRs
# gh can't fetch, include the commit body). Used by the whats-new skill (.claude/skills/whats-new).

set -eu

PBXPROJ_PATH="TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj"

# Only a tag clash ("would clobber existing tag", a local tag that differs from origin's) is survivable: the
# refs fetched fine and local tags are good enough. Anything else (offline, auth, wrong remote) leaves
# origin/main stale, so notes drafted from it would be wrong; stop and say why. Never --force here; that would
# move local tags without the user asking.
if ! fetch_err=$(git fetch --tags origin 2>&1); then
  if printf '%s' "$fetch_err" | grep -q 'would clobber existing tag'; then
    {
      echo "warning: 'git fetch --tags origin' rejected a tag; continuing with local tags:"
      printf '%s\n' "$fetch_err" | sed 's/^/  /'
      echo "hint: to realign local tags with origin, run: git fetch --tags --force origin"
    } >&2
  else
    {
      echo "error: 'git fetch --tags origin' failed, so origin/main may be stale; not drafting notes from it:"
      printf '%s\n' "$fetch_err" | sed 's/^/  /'
    } >&2
    exit 1
  fi
fi

BASE=${1:-$(git tag --list 'v*' --sort=-version:refname | head -n 1)}
if [ -z "$BASE" ]; then
  echo "error: no v* release tag found; pass a base ref explicitly." >&2
  exit 1
fi
END=${2:-origin/main}
for ref in "$BASE" "$END"; do
  if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
    echo "error: unknown revision '$ref'; pass a valid tag or branch." >&2
    exit 1
  fi
done

VERSION=$(git show "$END:$PBXPROJ_PATH" | grep -o 'MARKETING_VERSION = [0-9.]*;' | sort -u \
  | sed 's/MARKETING_VERSION = //; s/;//')

echo "# Changes since $BASE"
echo
echo "- Version being prepared (MARKETING_VERSION at $END): $VERSION"
echo "- Range: $BASE ($(git rev-parse --short "$BASE"))  →  $END ($(git rev-parse --short "$END"))"
echo

COMMITS=$(git log --first-parent --reverse --format='%H' "$BASE..$END")
if [ -z "$COMMITS" ]; then
  echo "_No commits since $BASE._"
  exit 0
fi

pr_details() {
  gh pr view "$1" --json labels,body \
    --template '{{if .labels}}Labels: {{range $i, $l := .labels}}{{if $i}}, {{end}}{{$l.name}}{{end}}{{"\n\n"}}{{end}}{{.body}}{{"\n"}}'
}

# Squash merges end in "(#N)"; merge commits start with "Merge pull request #N from".
pr_number() {
  printf '%s' "$1" | sed -n -e 's/.*(#\([0-9][0-9]*\))$/\1/p' -e 's/^Merge pull request #\([0-9][0-9]*\) from .*/\1/p'
}

for sha in $COMMITS; do
  subject=$(git log -1 --format='%s' "$sha")
  pr=$(pr_number "$subject")
  echo "## COMMIT: $subject"
  echo
  # Bodies are quoted so their own markdown headings don't read as new commits.
  {
    if [ -n "$pr" ] && command -v gh >/dev/null 2>&1 && details=$(pr_details "$pr" 2>/dev/null); then
      printf '%s\n' "$details"
    else
      if [ -n "$pr" ]; then
        echo "(PR #$pr description unavailable — gh missing or lookup failed; commit body below)"
        echo
      fi
      git log -1 --format='%b' "$sha"
    fi
  } | sed 's/^/> /'
  echo
done
