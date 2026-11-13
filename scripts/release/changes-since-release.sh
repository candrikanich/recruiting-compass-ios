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

die() {
  echo "error: $1" >&2
  [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/  /' >&2
  exit 1
}

# Branches come from a strict fetch with no tags: a stale origin/main would draft wrong notes, so any failure
# stops here. Tags are never fetched or read locally (a local tag can be stale or differ from origin's, e.g.
# "would clobber existing tag"); they are resolved from origin itself below.
if ! fetch_err=$(git fetch --no-tags origin 2>&1); then
  die "'git fetch --no-tags origin' failed, so origin/main may be stale; not drafting notes from it:" "$fetch_err"
fi

# "v1.0.3", "tags/v1.0.3", "refs/tags/v1.0.3" and "v1.0.3^0" all name the same tag.
tag_name() {
  printf '%s' "$1" | sed -e 's/^refs\/tags\///' -e 's/^tags\///' -e 's/\^0$//' -e 's/\^{commit}$//'
}

# Commit SHA of a tag on origin (peeled when annotated), or nothing when origin has no such tag.
origin_tag_commit() {
  tags=$(git ls-remote --tags origin "refs/tags/$1" "refs/tags/$1^{}" 2>&1) \
    || die "'git ls-remote --tags origin' failed:" "$tags"
  printf '%s\n' "$tags" | awk -v t="refs/tags/$1" -v p="refs/tags/$1^{}" '
    $2 == t { direct = $1 }
    $2 == p { peeled = $1 }
    END { print (peeled != "" ? peeled : direct) }'
}

# Prints "<commit-sha> <label>". Tags resolve from origin; anything else (branch, SHA, origin/main) via git.
resolve() {
  name=$(tag_name "$1")
  sha=$(origin_tag_commit "$name") || exit 1
  if [ -n "$sha" ]; then
    if ! git cat-file -e "$sha^{commit}" 2>/dev/null; then
      fetch_err=$(git fetch --no-tags origin "+refs/tags/$name" 2>&1) \
        || die "could not fetch tag '$name' from origin:" "$fetch_err"
    fi
    echo "$sha $name"
    return
  fi
  if git show-ref --verify --quiet "refs/tags/$name"; then
    die "tag '$name' exists only locally, not on origin; release notes use origin's tags."
  fi
  sha=$(git rev-parse --verify --quiet "$1^{commit}") || die "unknown revision '$1'; pass a valid tag or branch."
  echo "$sha $1"
}

if [ -n "${1:-}" ]; then
  BASE_REF=$1
else
  listed=$(git ls-remote --tags --refs origin 'refs/tags/v*' 2>&1) || die "'git ls-remote --tags origin' failed:" "$listed"
  newest=$(printf '%s\n' "$listed" | sed 's/.*refs\/tags\///' | sort -V | tail -n 1)
  [ -n "$newest" ] || die "no v* release tag found on origin; pass a base ref explicitly."
  BASE_REF=$newest
fi
END_REF=${2:-origin/main}

# Assigned first, then split: `set -- $(...)` would swallow a failed resolve.
resolved=$(resolve "$BASE_REF") || exit 1
BASE_SHA=${resolved% *} BASE=${resolved#* }
resolved=$(resolve "$END_REF") || exit 1
END_SHA=${resolved% *} END=${resolved#* }

VERSION=$(git show "$END_SHA:$PBXPROJ_PATH" | grep -o 'MARKETING_VERSION = [0-9.]*;' | sort -u \
  | sed 's/MARKETING_VERSION = //; s/;//')

echo "# Changes since $BASE"
echo
echo "- Version being prepared (MARKETING_VERSION at $END): $VERSION"
echo "- Range: $BASE ($(git rev-parse --short "$BASE_SHA"))  →  $END ($(git rev-parse --short "$END_SHA"))"
echo

COMMITS=$(git log --first-parent --reverse --format='%H' "$BASE_SHA..$END_SHA")
if [ -z "$COMMITS" ]; then
  echo "_No commits since $BASE._"
  exit 0
fi

pr_details() {
  gh pr view "$1" --json title,labels,body \
    --template 'Title: {{.title}}{{"\n"}}{{if .labels}}Labels: {{range $i, $l := .labels}}{{if $i}}, {{end}}{{$l.name}}{{end}}{{"\n\n"}}{{end}}{{.body}}{{"\n"}}'
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
