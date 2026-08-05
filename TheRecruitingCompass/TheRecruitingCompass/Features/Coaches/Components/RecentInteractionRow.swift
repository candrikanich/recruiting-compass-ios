import SwiftUI

struct RecentInteractionRow: View {
  let interaction: Interaction

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 32 : 24
  }

  var body: some View {
    HStack(spacing: 12) {
      // Type icon with colored background
      ZStack {
        Circle()
          .fill(interaction.type.tintColor.opacity(0.15))
          .frame(width: iconSize + 12, height: iconSize + 12)

        Image(systemName: interaction.type.iconName)
          .font(.system(size: iconSize * 0.6))
          .foregroundStyle(interaction.type.tintColor)
      }
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(interaction.type.displayName)
            .font(sizeCategory.isAccessibilityCategory ? .body.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(.primary)

          if let sentiment = interaction.sentiment {
            Text(sentiment.displayName)
              .font(.caption.weight(.medium))
              .foregroundStyle(sentiment.badgeColor.foregroundColor)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(sentiment.badgeColor.backgroundColor)
              .clipShape(Capsule())
          }
        }

        if let subject = interaction.subject, !subject.isEmpty {
          Text(subject)
            .font(sizeCategory.isAccessibilityCategory ? .callout : .caption)
            .foregroundStyle(Color.secondaryText)
            .lineLimit(1)
        }
      }

      Spacer()

      Text(interaction.displayDate, style: .date)
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityText)
  }

  private var accessibilityText: String {
    var text = String(localized: "\(interaction.type.displayName) on \(interaction.displayDate.formatted(date: .abbreviated, time: .omitted))")

    if let sentiment = interaction.sentiment {
      text += String(localized: ", \(sentiment.displayName)")
    }

    if let subject = interaction.subject, !subject.isEmpty {
      text += String(localized: ", \(subject)")
    }

    return text
  }
}

#Preview {
  VStack(spacing: 0) {
    RecentInteractionRow(
      interaction: Interaction(
        id: "1",
        type: .email,
        direction: .outbound,
        schoolId: "school-1",
        coachId: "coach-1",
        subject: "Following up on our conversation",
        content: nil,
        sentiment: .positive,
        occurredAt: "2026-02-08T10:00:00Z",
        loggedBy: "user-1",
        attachments: nil,
        familyUnitId: "family-1",
        createdAt: "2026-02-08T10:00:00Z",
        updatedAt: nil
      )
    )
    Divider()
    RecentInteractionRow(
      interaction: Interaction(
        id: "2",
        type: .phoneCall,
        direction: .inbound,
        schoolId: "school-1",
        coachId: "coach-1",
        subject: nil,
        content: nil,
        sentiment: .veryPositive,
        occurredAt: "2026-02-05T14:30:00Z",
        loggedBy: "user-1",
        attachments: nil,
        familyUnitId: "family-1",
        createdAt: "2026-02-05T14:30:00Z",
        updatedAt: nil
      )
    )
  }
  .padding()
}
