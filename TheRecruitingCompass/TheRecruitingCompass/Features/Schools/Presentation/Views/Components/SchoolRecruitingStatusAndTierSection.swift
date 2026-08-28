import SwiftUI

/// Single section with a recruiting status dropdown, matching web detail page.
struct SchoolRecruitingStatusAndTierSection: View {
  let currentStatus: SchoolStatus
  let isUpdatingStatus: Bool
  let onStatusChange: (SchoolStatus) async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recruiting Status")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        if isUpdatingStatus {
          ProgressView()
            .scaleEffect(0.8)
            .accessibilityLabel(String(localized: "Updating"))
        }

        Spacer()
      }

      SchoolStatusStepper(
        currentStatus: currentStatus,
        isUpdating: isUpdatingStatus,
        onSelect: onStatusChange
      )
      .accessibilityIdentifier("status-stepper")
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
  }
}

#Preview {
  SchoolRecruitingStatusAndTierSection(
    currentStatus: .interested,
    isUpdatingStatus: false,
    onStatusChange: { _ in }
  )
  .padding(.vertical)
}
