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

      Menu {
        ForEach(SchoolStatus.allCases.filter { $0 != .unknown }, id: \.self) { status in
          Button {
            Task { await onStatusChange(status) }
          } label: {
            HStack {
              Text(status.displayName)
              if status == currentStatus {
                Image(systemName: "checkmark")
              }
            }
          }
        }
      } label: {
        HStack {
          Text(currentStatus.displayName)
            .foregroundStyle(.primary)
          Spacer()
          Image(systemName: "chevron.up.chevron.down")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 8))
      }
      .accessibilityIdentifier("status-picker-button")
      .accessibilityLabel(String(localized: "Recruiting status: \(currentStatus.displayName)"))
      .accessibilityHint("Double tap to change status")
      .disabled(isUpdatingStatus)
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
