import SwiftUI

struct OfferCard: View {
  let offer: Offer
  let schoolName: String
  let isSelected: Bool
  let onToggleSelection: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(offer.status.statusColor)
        .frame(width: 4)
        .accessibilityHidden(true)

      HStack(spacing: 12) {
        Button {
          onToggleSelection()
        } label: {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentBlue : .secondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("offer_checkbox_\(offer.id)")
        .accessibilityLabel("Select for comparison")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(schoolName)
              .font(.headline)
              .foregroundStyle(.primary)
              .lineLimit(1)

            Spacer()

            OfferStatusBadge(status: offer.status)
          }

          Text(offer.offerType.displayName)
            .font(.subheadline)
            .foregroundStyle(.secondary)

          HStack(spacing: 12) {
            if let amount = offer.formattedAmount {
              Label(amount, systemImage: "dollarsign.circle")
                .font(.subheadline)
                .foregroundStyle(.primary)
            }

            if let pct = offer.formattedPercentage {
              Label(pct, systemImage: "percent")
                .font(.subheadline)
                .foregroundStyle(.primary)
            }
          }

          HStack(spacing: 4) {
            Image(systemName: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)

            Text(DateFormatting.mediumDate(offer.displayOfferDate))
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let deadline = offer.displayDeadlineDate {
            deadlineRow(deadline)
          }

          if let notes = offer.notes, !notes.isEmpty {
            Text(notes)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Tap to view offer details")

        Button(role: .destructive) {
          onDelete()
        } label: {
          Image(systemName: "trash")
            .font(.subheadline)
            .foregroundStyle(Color.errorRed)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("offer_delete_button_\(offer.id)")
        .accessibilityLabel("Delete offer from \(schoolName)")
        .accessibilityHint("Double tap to delete this offer")
      }
      .padding(12)
    }
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityIdentifier("offer_card_\(offer.id)")
  }

  private var cardAccessibilityLabel: String {
    var parts = ["Offer from \(schoolName)", offer.status.displayName, offer.offerType.displayName]
    if let amount = offer.formattedAmount { parts.append(amount) }
    if let pct = offer.formattedPercentage { parts.append(pct) }
    if let days = offer.daysUntilDeadline {
      if days < 0 {
        parts.append("Overdue")
      } else {
        parts.append("Deadline in \(days) day\(days == 1 ? "" : "s")")
      }
    }
    return parts.joined(separator: ", ")
  }

  @ViewBuilder
  private func deadlineRow(_ deadline: Date) -> some View {
    let urgency = offer.deadlineUrgency
    HStack(spacing: 4) {
      Image(systemName: "clock")
        .font(.caption)
        .foregroundStyle(urgency.color)
        .accessibilityHidden(true)

      Text("Deadline: \(DateFormatting.mediumDate(deadline))")
        .font(.caption)
        .foregroundStyle(urgency.color)

      if let label = urgency.label {
        Text("(\(label))")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(urgency.color)
      }
    }
  }
}

private struct OfferStatusBadge: View {
  let status: OfferStatus

  var body: some View {
    Text(status.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(status.statusColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(status.statusColor.opacity(0.1))
      .clipShape(.rect(cornerRadius: 6))
      .accessibilityLabel("Status: \(status.displayName)")
  }
}
