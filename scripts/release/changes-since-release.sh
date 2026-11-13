#!/bin/sh
# Lists everything merged since the last release tag, as raw material for release notes.
#
#   scripts/release/changes-since-release.sh                          # newest v* tag on origin → origin/main
#   scripts/release/changes-since-release.sh v1.0.1                   # a release tag → origin/main
#   scripts/release/changes-since-release.sh v1.0.1 <40-hex-sha>      # hotfix: tag → the commit being released
#
# An endpoint is a release tag (vX.Y.Z, optionally refs/tags/-prefixed; resolved from origin, never from local
# tags) or a full 40-character lowercase commit SHA; the end may also be omitted or origin/main. Nothing else.
# The end must be whatever the release build is made from — for a hotfix that's the hotfix commit
# (`git rev-parse origin/hotfix/x`), not main, or the notes would advertise unreleased work sitting on main.
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

# Branches come from a strict fetch with --no-tags: a stale origin/main would draft wrong notes, so any failure
# stops here. Local tags are never read (a local tag can be stale or differ from origin's); tags are resolved
# from origin itself below, which fetches a tag's commit only when it is missing locally, and writes no tag.
if ! fetch_err=$(git fetch --no-tags origin 2>&1); then
  die "'git fetch --no-tags origin' failed, so origin/main may be stale; not drafting notes from it:" "$fetch_err"
fi

# Commit SHA of a tag on origin (peeled when annotated), or nothing when origin has no such tag. ls-remote's
# stderr is left alone (it is not tag data and is the explanation if the call fails).
origin_tag_commit() {
  tags=$(git ls-remote --tags origin "refs/tags/$1" "refs/tags/$1^{}") \
    || die "'git ls-remote --tags origin' failed; not drafting notes from stale tags."
  printf '%s\n' "$tags" | awk -v t="refs/tags/$1" -v p="refs/tags/$1^{}" '
    $2 == t { direct = $1 }
    $2 == p { peeled = $1 }
    END { print (peeled != "" ? peeled : direct) }'
}

BAD_ENDPOINT="endpoint must be a release tag (vX.Y.Z) or a full commit SHA"

# Prints "<commit-sha> <label>". A 40-hex SHA is checked before any tag lookup and resolved as a commit object,
# never as a ref. A tag is resolved only from origin.
resolve() {
  case $1 in
    *[!0123456789abcdef]*) ;;
    *)
      if [ "${#1}" -eq 40 ]; then
        sha=$(git -c advice.objectNameWarning=false rev-parse --verify --quiet "$1^{commit}") \
          || die "$BAD_ENDPOINT: '$1' is not a commit in this repository."
        echo "$sha $1"
        return
      fi
      ;;
  esac
  name=${1#refs/tags/}
  case $name in
    *'
'*) die "$BAD_ENDPOINT, got '$1'." ;;
  esac
  printf '%s' "$name" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || die "$BAD_ENDPOINT, got '$1'."
  sha=$(origin_tag_commit "$name") || exit 1
  if [ -z "$sha" ]; then
    if git show-ref --verify --quiet "refs/tags/$name"; then
      die "tag '$name' exists only locally, not on origin; release notes use origin's tags."
    fi
    die "unknown revision '$1': no such release tag on origin."
  fi
  if ! git cat-file -e "$sha^{commit}" 2>/dev/null; then
    fetch_err=$(git fetch --no-tags origin "+refs/tags/$name" 2>&1) \
      || die "could not fetch tag '$name' from origin:" "$fetch_err"
    git cat-file -e "$sha^{commit}" 2>/dev/null \
      || die "tag '$name' is on origin but its commit '$sha' was not fetched."
  fi
  echo "$sha $name"
}

if [ $# -ge 1 ]; then
  BASE_REF=$1
else
  listed=$(git ls-remote --tags --refs origin 'refs/tags/v*') \
    || die "'git ls-remote --tags origin' failed; not drafting notes from stale tags."
  newest=$(printf '%s\n' "$listed" | sed 's/.*refs\/tags\///' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
  [ -n "$newest" ] || die "no v* release tag found on origin; pass a release tag explicitly."
  BASE_REF=$newest
fi

# Assigned first, then split: `set -- $(...)` would swallow a failed resolve.
resolved=$(resolve "$BASE_REF") || exit 1
BASE_SHA=${resolved% *} BASE=${resolved#* }
# The default end is spelled out as a full ref so a local branch or tag named origin/main cannot take over.
if [ $# -lt 2 ] || [ "$2" = origin/main ]; then
  END_SHA=$(git rev-parse --verify --quiet "refs/remotes/origin/main^{commit}") || die "origin/main not found."
  END=origin/main
else
  resolved=$(resolve "$2") || exit 1
  END_SHA=${resolved% *} END=${resolved#* }
fi

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
