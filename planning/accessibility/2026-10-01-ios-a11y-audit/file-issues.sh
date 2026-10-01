#!/bin/zsh
# Files the drafts in issues/ on GitHub: an `accessibility` label, one tracking issue, then one issue per draft.
# Usage: planning/accessibility/2026-10-01-ios-a11y-audit/file-issues.sh
set -euo pipefail
DIR=${0:A:h}
REPO=candrikanich/recruiting-compass-ios

gh label create accessibility -R $REPO --color 0E8A16 \
  --description "VoiceOver, Voice Control, Larger Text, contrast, motion" 2>/dev/null || true

TRACK_URL=$(gh issue create -R $REPO --title "iOS accessibility audit (2026-10-01): tracking" --label accessibility \
  --body "Tracking issue for the 2026-10-01 iOS accessibility audit. Report: planning/accessibility/2026-10-01-ios-a11y-audit/README.md")
TRACK=${TRACK_URL##*/}

typeset -A TITLES LABELS
TITLES=(
  01-interaction-content 'VoiceOver reads "Interaction content" instead of the interaction message'
  02-timeline-phase-card 'Timeline: tasks inside a phase card cannot be read or completed with VoiceOver'
  03-performance-export 'Performance export share sheet dismisses itself after 0.5 s'
  04-document-viewer 'Document viewer hides Close and every other control after 3 s on videos'
  05-status-messages 'Results and errors are never announced; success messages vanish in 2-3 s'
  06-combined-elements 'Merged accessibility elements swallow buttons and drop visible information'
  07-contrast 'Colour contrast below WCAG AA in light and dark mode'
  08-color-only 'Meaning conveyed by colour alone (recruiting status, Personal Fit, onboarding error)'
  09-larger-text 'Larger Text: layouts that truncate, clip or cannot scroll at accessibility sizes'
  10-hit-targets 'Hit targets under 44 pt, including full-width buttons where only the word is tappable'
  11-names-and-forms 'Unnamed or misnamed controls and form fields; state not exposed'
  12-voice-control 'Voice Control: spoken names that do not contain the visible text'
  13-charts 'Analytics charts lack Audio Graphs and per-point access'
  14-polish 'Accessibility polish: Reduce Motion, raw values, noise, unconfirmed discard, dead code'
)
LABELS=(
  01-interaction-content accessibility,bug
  02-timeline-phase-card accessibility,bug
  03-performance-export accessibility,bug
  04-document-viewer accessibility,bug
  05-status-messages accessibility
  06-combined-elements accessibility
  07-contrast accessibility,UI
  08-color-only accessibility,UI
  09-larger-text accessibility,UI
  10-hit-targets accessibility,UI
  11-names-and-forms accessibility
  12-voice-control accessibility
  13-charts accessibility
  14-polish accessibility
)

CHECKLIST=""
for key in ${(ok)TITLES}; do
  URL=$(sed "s|tracking issue: TRACKING|tracking issue: #$TRACK|" $DIR/issues/$key.md \
    | gh issue create -R $REPO --title "${TITLES[$key]}" --label "${LABELS[$key]}" --body-file -)
  echo "$key  $URL"
  CHECKLIST+="- [ ] #${URL##*/}"$'\n'
done

gh issue edit $TRACK -R $REPO --body "Tracking issue for the 2026-10-01 iOS accessibility audit.
Report: \`planning/accessibility/2026-10-01-ios-a11y-audit/README.md\`

$CHECKLIST"
echo "tracking  $TRACK_URL"
