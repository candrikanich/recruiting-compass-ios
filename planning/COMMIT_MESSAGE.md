# Commit Message

```
refactor: extract shared filter components and utilities

Extract and consolidate ~450 lines of duplicated code from Coaches, Schools,
and Interactions features into reusable shared components.

**New Shared Components:**
- FilterMenuButton: Reusable filter menu button with capsule/rounded styles
- FilterChip: Active filter chip with remove button (outlined/filled styles)
- FilterChipContainer: Horizontal scroll container with clear all button
- EntityNameLookup: School/Coach name lookup utilities
- DateFormatting: Cached date formatters (performance improvement)

**Updated Features:**
- Coaches: CoachFilterBar, ActiveFilterChips, CoachesListViewModel
- Schools: SchoolFilterBar, SchoolActiveFilterChips
- Interactions: InteractionFilterBar, InteractionActiveFilterChips,
  InteractionsListViewModel, InteractionCard

**Impact:**
- Code reduction: ~450 lines of duplicated code eliminated
- Performance: Cached date formatters improve rendering performance
- Consistency: Same UI patterns across all list features
- Accessibility: All WCAG AA features preserved (44pt hit targets, VoiceFor labels, Dynamic Type)
- Tests: All 538 existing tests passing (0 regressions)
- Build: Clean (0 errors, 0 warnings)

**Technical Details:**
- Style enums enable flexible component reuse (.capsule vs .rounded, .outlined vs .filled)
- Generic ViewBuilder pattern allows feature-specific chip content
- Static utility methods for O(1) name lookups
- Backward compatible: No API changes to consuming features

See planning/SHARED_COMPONENTS_COMPLETION.md for full details.
```
