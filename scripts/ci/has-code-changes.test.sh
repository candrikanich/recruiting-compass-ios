#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(dirname "$0")/has-code-changes.sh"
failures=0

expect() {
  local expected="$1" label="$2" paths="$3" actual
  actual="$(printf '%s' "$paths" | "$SCRIPT")"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $label — expected $expected, got $actual"
    failures=$((failures + 1))
  fi
}

expect false "planning only" $'planning/lessons.md\n'
expect false "docs, root markdown and skills" $'docs/RELEASE.md\nCLAUDE.md\n.claude/skills/release/SKILL.md\n'
expect false "App Store metadata" $'fastlane/metadata/en-US/release_notes.txt\n'
expect false "markdown beside the Xcode project" $'TheRecruitingCompass/UI/Screens/HOW_TO_CREATE_SCREENS.md\n'

expect true "swift source" $'TheRecruitingCompass/TheRecruitingCompass/App/RootView.swift\n'
expect true "docs mixed with source" $'planning/lessons.md\nTheRecruitingCompass/TheRecruitingCompassTests/FooTests.swift\n'
expect true "markdown inside a target is a bundled resource" $'TheRecruitingCompass/TheRecruitingCompass/Resources/faq.md\n'
expect true "project file" $'TheRecruitingCompass/TheRecruitingCompass.xcodeproj/project.pbxproj\n'
expect true "workflow" $'.github/workflows/ci.yml\n'
expect true "lint config" $'.swiftlint.yml\n'
expect true "fastlane lanes" $'fastlane/Fastfile\n'
expect true "path that merely contains docs/" $'scripts/docs/build.sh\n'
expect true "no paths means the diff could not be computed" ''

if [ "$failures" -gt 0 ]; then
  echo "$failures classifier case(s) failed"
  exit 1
fi
echo "has-code-changes: all cases pass"
