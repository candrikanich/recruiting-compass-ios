import SwiftUI

/// "School Fit" card wrapping Personal Fit (first) then Academic Fit (second),
/// mirroring web components/School/SchoolSidebar.vue + SchoolFitSignals.vue.
struct SchoolFitSection: View {
  let personalFit: PersonalFitAnalysis?
  let academicFit: AcademicFitAnalysis?
  let isEnriching: Bool
  let enrichError: String?
  let onLookup: () -> Void

  var body: some View {
    if personalFit != nil || academicFit != nil {
      VStack(alignment: .leading, spacing: 16) {
        Text("School Fit").font(.title3).fontWeight(.semibold)
          .accessibilityAddTraits(.isHeader)

        if let personalFit {
          PersonalFitCard(analysis: personalFit)
        }
        if let academicFit {
          AcademicFitCard(analysis: academicFit, isEnriching: isEnriching,
                          enrichError: enrichError, onLookup: onLookup)
        }
        Text("Academic data from the U.S. College Scorecard.")
          .font(.caption2).foregroundStyle(.secondary)
      }
      .padding(.horizontal)
    }
  }
}
