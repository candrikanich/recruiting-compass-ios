import SwiftUI

/// Single section with one row: recruiting status (menu) and priority tier (dropdown), matching web detail page.
struct SchoolRecruitingStatusAndTierSection: View {
  let currentStatus: SchoolStatus
  let selectedTier: PriorityTier?
  let isUpdatingStatus: Bool
  let isUpdatingTier: Bool
  let onStatusChange: (SchoolStatus) async -> Void
  let onTierSelect: (PriorityTier?) async -> Void

  private var isUpdating: Bool { isUpdatingStatus || isUpdatingTier }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recruiting Status & Tier")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        if isUpdating {
          ProgressView()
            .scaleEffect(0.8)
            .accessibilityLabel("Updating")
        }

        Spacer()
      }

      HStack(spacing: 12) {
        // Status dropdown
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
        .accessibilityLabel("Recruiting status: \(currentStatus.displayName)")
        .accessibilityHint("Double tap to change status")
        .disabled(isUpdating)

        // Tier dropdown
        Menu {
          Button {
            Task { await onTierSelect(nil) }
          } label: {
            HStack {
              Text("None")
              if selectedTier == nil {
                Image(systemName: "checkmark")
              }
            }
          }
          ForEach(PriorityTier.allCases, id: \.self) { tier in
            Button {
              Task { await onTierSelect(tier) }
            } label: {
              HStack {
                Text(tierDropdownLabel(tier))
                if selectedTier == tier {
                  Image(systemName: "checkmark")
                }
              }
            }
          }
        } label: {
          HStack {
            Text(selectedTier.map { tierDropdownLabel($0) } ?? "None")
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
        .accessibilityIdentifier("tier-picker-button")
        .accessibilityLabel("Priority tier: \(selectedTier.map { tierDropdownLabel($0) } ?? "None")")
        .accessibilityHint("Double tap to change tier")
        .disabled(isUpdating)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
  }

  private func tierDropdownLabel(_ tier: PriorityTier) -> String {
    "Tier \(tier.displayName)"
  }
}

#Preview {
  SchoolRecruitingStatusAndTierSection(
    currentStatus: .interested,
    selectedTier: .a,
    isUpdatingStatus: false,
    isUpdatingTier: false,
    onStatusChange: { _ in },
    onTierSelect: { _ in }
  )
  .padding(.vertical)
}
