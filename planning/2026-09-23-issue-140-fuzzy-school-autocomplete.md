# Issue #140 — Add School autocomplete typo tolerance

## Findings (issue premise corrected)
- Dropdown is NOT fed by `NcaaDatabase`. Path: `AddSchoolViewModel.performAutocompleteSearch` →
  `CollegeScorecardService.searchColleges` → web proxy `/api/colleges/search` → College Scorecard
  `school.name=` (word/prefix match, zero typo tolerance). "Michgan" → empty list.
- `NcaaDatabase.lookup` (division auto-fill) already has whole-string Levenshtein ≤2. Unrelated to the dropdown.
- Web #606 (schools-table FTS) is a different data path; not reusable here.

## Approach (iOS-only, issue option 1 in spirit)
When Scorecard returns 0 results for a query, ask the bundled NCAA dataset for the nearest school
names (token-aware fuzzy), retry Scorecard with the best correction, and show those results.
Recruiting app → NCAA list covers the schools users search for.

## Steps (TDD)
1. RED: `NcaaDatabaseTests` — `suggestNames(for:)` corrects "Michgan"→Michigan, tolerates transposition,
   returns [] for nonsense, ranks closest first, caps count.
2. GREEN: `NcaaDatabase.suggestNames(for:limit:)` — token-level Levenshtein (threshold scales with length),
   uses existing `String.levenshteinDistance`. Add to `NcaaDatabaseManaging` with default `[]` extension
   so existing mocks compile.
3. RED: `AddSchoolViewModelTests` — empty Scorecard result + suggestion → retry, results shown;
   no suggestion → stays empty; non-empty first result → no retry.
4. GREEN: retry in `performAutocompleteSearch`.
5. Verify: affected test classes + `xcodebuild build`. Ship via PR (draft), `Closes #140`.

## Out of scope / follow-up
- Web proxy still has no fuzzy search (web dropdown has same gap) — note on PR, separate web issue.
