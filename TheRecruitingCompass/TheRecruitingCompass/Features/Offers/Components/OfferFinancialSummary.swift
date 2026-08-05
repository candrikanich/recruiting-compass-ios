import SwiftUI

struct OfferFinancialSummary: View {
  let formattedAmount: String?
  let formattedPercentage: String?
  let deadlineText: String
  let deadlineUrgency: DeadlineUrgency
  let formattedDeadlineDate: String

  var body: some View {
    HStack(spacing: 12) {
      financialCard(
        label: "Scholarship Amount",
        value: formattedAmount ?? "---",
        accessibilityText: String(localized: "Scholarship amount: \(formattedAmount ?? "Not specified")"),
        color: .primary,
        identifier: "offer-amount-card"
      )

      financialCard(
        label: "Scholarship %",
        value: formattedPercentage ?? "---",
        accessibilityText: String(localized: "Scholarship percentage: \(formattedPercentage ?? "Not specified")"),
        color: .primary,
        identifier: "offer-percentage-card"
      )

      VStack(spacing: 4) {
        Text("Deadline")
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(deadlineText)
          .font(.title2)
          .bold()
          .foregroundStyle(deadlineUrgency.color)

        if let urgencyLabel = deadlineUrgency.label {
          Text(urgencyLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(deadlineUrgency.color)
        }

        Text(formattedDeadlineDate)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .accessibilityIdentifier("offer-deadline-card")
      .accessibilityElement(children: .combine)
      .accessibilityLabel(deadlineAccessibilityLabel)
    }
    .padding(.horizontal)
  }

  private var deadlineAccessibilityLabel: String {
    switch deadlineUrgency {
    case .none:
      return String(localized: "No deadline set")
    case .normal:
      return String(localized: "Deadline in \(deadlineText), \(formattedDeadlineDate)")
    case .urgent:
      return String(localized: "Urgent: Deadline in \(deadlineText), \(formattedDeadlineDate)")
    case .critical:
      return String(localized: "Critical: Deadline in \(deadlineText), \(formattedDeadlineDate)")
    case .overdue:
      return String(localized: "Overdue: Deadline was \(deadlineText), \(formattedDeadlineDate)")
    }
  }

  private func financialCard(
    label: String,
    value: String,
    accessibilityText: String,
    color: Color,
    identifier: String
  ) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(value)
        .font(.title2)
        .bold()
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityIdentifier(identifier)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
  }
}

#Preview {
  OfferFinancialSummary(
    formattedAmount: "$40,000",
    formattedPercentage: "80%",
    deadlineText: "14d",
    deadlineUrgency: .urgent,
    formattedDeadlineDate: "Mar 15, 2026"
  )
}
