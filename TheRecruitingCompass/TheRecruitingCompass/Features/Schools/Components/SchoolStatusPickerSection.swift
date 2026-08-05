import SwiftUI
import Foundation

/// Section displaying and allowing updates to school recruiting status
struct SchoolStatusPickerSection: View {
  let currentStatus: SchoolStatus
  let isUpdating: Bool
  let onStatusChange: (SchoolStatus) async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recruiting Status")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      HStack {
        Menu {
          ForEach(SchoolStatus.allCases, id: \.self) { status in
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
        .disabled(isUpdating)

        if isUpdating {
          ProgressView()
            .accessibilityLabel(String(localized: "Updating status"))
        }
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Recruiting status: \(currentStatus.displayName)")
    .accessibilityHint("Double tap to change status")
  }
}

#Preview("Interested Status") {
  SchoolStatusPickerSection(
    currentStatus: .interested,
    isUpdating: false,
    onStatusChange: { _ in }
  )
}

#Preview("Updating") {
  SchoolStatusPickerSection(
    currentStatus: .committed,
    isUpdating: true,
    onStatusChange: { _ in }
  )
}
