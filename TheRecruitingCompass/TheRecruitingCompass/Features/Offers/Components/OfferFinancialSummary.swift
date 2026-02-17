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
        accessibilityText: "Scholarship amount: \(formattedAmount ?? "Not specified")",
        color: .primary,
        identifier: "offer-amount-card"
      )

      financialCard(
        label: "Scholarship %",
        value: formattedPercentage ?? "---",
        accessibilityText: "Scholarship percentage: \(formattedPercentage ?? "Not specified")",
        color: .primary,
        identifier: "offer-percentage-card"
      )

      VStack(spacing: 4) {
        Text("Deadline")
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(deadlineText)
          .font(.title2)
          .fontWeight(.bold)
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
      return "No deadline set"
    case .normal:
      return "Deadline in \(deadlineText), \(formattedDeadlineDate)"
    case .urgent:
      return "Urgent: Deadline in \(deadlineText), \(formattedDeadlineDate)"
    case .critical:
      return "Critical: Deadline in \(deadlineText), \(formattedDeadlineDate)"
    case .overdue:
      return "Overdue: Deadline was \(deadlineText), \(formattedDeadlineDate)"
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
        .fontWeight(.bold)
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
