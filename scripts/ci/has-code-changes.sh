#!/usr/bin/env bash
# Reads changed paths on stdin and prints "false" only when every one is
# documentation, so CI can skip the macOS jobs. Anything unrecognised counts as
# code, and so does an empty list (the diff could not be computed).
set -euo pipefail

is_docs() {
  case "$1" in
    # Synchronized groups bundle any file under a target directory, markdown included.
    TheRecruitingCompass/TheRecruitingCompass*) return 1 ;;
    planning/* | docs/* | .claude/* | fastlane/metadata/* | *.md) return 0 ;;
    *) return 1 ;;
  esac
}

saw_path=false
while IFS= read -r path; do
  [ -z "$path" ] && continue
  saw_path=true
  if ! is_docs "$path"; then
    echo true
    exit 0
  fi
done

if [ "$saw_path" = true ]; then echo false; else echo true; fi
