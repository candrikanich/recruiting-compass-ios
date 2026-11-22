import SwiftUI

/// A parent's first-run card while the athlete has not joined: the school they added and read-only next steps for
/// the athlete's grade. Deliberately no buttons, no status score and no completed state: the athlete does the steps.
struct PendingAthleteStepsCard: View {
  let heading: String
  let note: String
  let favoriteSchoolName: String?
  let steps: [WhatMattersItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let favoriteSchoolName {
        (Text(FirstRunCopy.pendingTopSchoolLabel) + Text(favoriteSchoolName).fontWeight(.semibold))
          .font(.brand(.subheadline))
          .foregroundStyle(.secondary)
      }

      if !steps.isEmpty {
        Text(heading)
          .font(.brand(.subheadline, weight: .semibold))
          .accessibilityAddTraits(.isHeader)
        Text(note)
          .font(.brand(.caption))
          .foregroundStyle(.secondary)
        ForEach(steps) { step in
          VStack(alignment: .leading, spacing: 2) {
            Text(step.title)
              .font(.brand(.subheadline, weight: .medium))
            Text(step.whyItMatters)
              .font(.brand(.caption))
              .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityIdentifier("pendingAthleteSteps")
  }
}

#Preview {
  PendingAthleteStepsCard(
    heading: "Next steps for Riley",
    note: FirstRunCopy.pendingStepsNote(athleteFirstName: "Riley"),
    favoriteSchoolName: "State University",
    steps: [
      WhatMattersItem(
        taskId: "1", title: "Take the PSAT",
        whyItMatters: "It is the practice run for the SAT.", category: "academic", priority: 10, isRequired: true
      )
    ]
  )
  .padding()
}
