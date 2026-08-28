import SwiftUI

struct SchoolAttributionSection: View {
  let createdBy: String?
  let createdAt: String
  let updatedBy: String?
  let updatedAt: String

  var body: some View {
    VStack(spacing: 8) {
      Divider()
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        AttributionRow(
          label: String(localized: "Created"),
          userId: createdBy,
          date: createdAt
        )

        AttributionRow(
          label: String(localized: "Updated"),
          userId: updatedBy,
          date: updatedAt
        )
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
  }
}

private struct AttributionRow: View {
  let label: String
  let userId: String?
  let date: String

  private var formattedDate: String {
    guard let parsedDate = ISO8601DateFormatter().date(from: date) else {
      return String(localized: "Unknown")
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: parsedDate)
  }

  var body: some View {
    HStack(spacing: 4) {
      Text(label + ":")
        .fontWeight(.medium)

      Text(formattedDate)

      if let userId {
        Text("by \(userId)")
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    if let userId {
      return String(localized: "\(label) \(formattedDate) by \(userId)")
    } else {
      return String(localized: "\(label) \(formattedDate)")
    }
  }
}

#Preview {
  VStack(spacing: 0) {
    Rectangle()
      .fill(Color.gray.opacity(0.1))
      .frame(height: 200)

    SchoolAttributionSection(
      createdBy: "user-123",
      createdAt: "2024-01-15T10:30:00Z",
      updatedBy: "user-456",
      updatedAt: "2024-02-10T14:45:00Z"
    )
  }
}
