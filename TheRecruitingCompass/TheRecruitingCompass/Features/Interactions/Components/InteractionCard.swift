import SwiftUI

struct InteractionCard: View {
  let interaction: Interaction
  let schoolName: String?
  let coachName: String?
  var onDelete: () -> Void = {}

  @Environment(\.sizeCategory) private var sizeCategory
  @ScaledMetric(relativeTo: .body) private var iconImageSize: CGFloat = 18

  var deleteAccessibilityLabel: String { "Delete \(interaction.type.displayName) interaction" }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      cardContent
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(accessibilityHint)

      deleteButton
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Surface.card)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .brandShadowSm()
  }

  @ViewBuilder
  private var deleteButton: some View {
    Button(role: .destructive, action: onDelete) {
      Image(systemName: "trash")
        .font(.subheadline)
        .foregroundStyle(Color.errorRed)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(deleteAccessibilityLabel)
    .accessibilityHint("Double tap to delete this interaction")
  }

  @ViewBuilder
  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header: Type icon, badges
      HStack(spacing: 12) {
        // Type icon
        ZStack {
          Circle()
            .fill(interaction.type.tintColor.opacity(0.15))
            .frame(width: iconSize, height: iconSize)

          Image(systemName: interaction.type.iconName)
            .font(.system(size: iconImageSize))
            .foregroundStyle(interaction.type.tintColor)
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(interaction.type.displayName)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundStyle(.primary)

            DirectionBadge(direction: interaction.direction)
          }

          if let sentiment = interaction.sentiment {
            SentimentBadge(sentiment: sentiment)
          }
        }

        Spacer()

        if interaction.hasAttachments {
          AttachmentIndicator(count: interaction.attachmentCount)
        }
      }

      // Subject
      if let subject = interaction.subject, !subject.isEmpty {
        Text(subject)
          .font(.headline)
          .lineLimit(1)
          .foregroundStyle(.primary)
      }

      // School and Coach
      if schoolName != nil || coachName != nil {
        HStack(spacing: 4) {
          if let schoolName {
            Text(schoolName)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          if schoolName != nil && coachName != nil {
            Text("•")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          if let coachName {
            Text(coachName)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .lineLimit(1)
      }

      // Content preview
      if let content = interaction.content, !content.isEmpty {
        Text(content)
          .font(.body)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      // Date
      HStack(spacing: 4) {
        Image(systemName: "calendar")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)

        Text(DateFormatting.mediumDateShortTime(interaction.displayDate))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Computed Properties

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 48 : 40
  }

  var accessibilityHint: String { "Tap to view details" }

  var accessibilityLabel: String {
    var parts: [String] = []

    parts.append(interaction.type.displayName)
    parts.append(interaction.direction.displayName)

    if let subject = interaction.subject {
      parts.append(subject)
    }

    if let schoolName {
      parts.append("at \(schoolName)")
    }

    if let coachName {
      parts.append("with \(coachName)")
    }

    if let sentiment = interaction.sentiment {
      parts.append(sentiment.displayName)
    }

    parts.append(DateFormatting.mediumDateShortTime(interaction.displayDate))

    return parts.joined(separator: ", ")
  }

}

// MARK: - Supporting Views

struct DirectionBadge: View {
  let direction: Direction

  var body: some View {
    Text(direction.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(direction.badgeColor.foregroundColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(direction.badgeColor.backgroundColor)
      .clipShape(.rect(cornerRadius: 6))
  }
}

struct SentimentBadge: View {
  let sentiment: Sentiment

  var body: some View {
    Text(sentiment.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(sentiment.badgeColor.foregroundColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(sentiment.badgeColor.backgroundColor)
      .clipShape(.rect(cornerRadius: 6))
  }
}

struct AttachmentIndicator: View {
  let count: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "paperclip")
        .font(.caption)
        .accessibilityHidden(true)

      Text("\(count)")
        .font(.caption)
        .fontWeight(.medium)
    }
    .foregroundStyle(.secondary)
    .accessibilityLabel(accessibilityLabel)
  }

  var accessibilityLabel: String {
    "\(count) attachment\(count == 1 ? "" : "s")"
  }
}

#Preview {
  let interaction = Interaction(
    id: "1",
    type: .email,
    direction: .outbound,
    schoolId: "school1",
    coachId: "coach1",
    subject: "Follow-up on Camp Visit",
    content: "Thank you for taking the time to meet with me at the summer camp. I'm very interested in learning more about the program...",
    sentiment: .veryPositive,
    occurredAt: ISO8601DateFormatter().string(from: Date()),
    loggedBy: "user1",
    attachments: ["file1.pdf", "file2.jpg"],
    familyUnitId: "family1",
    createdAt: ISO8601DateFormatter().string(from: Date()),
    updatedAt: ISO8601DateFormatter().string(from: Date())
  )

  InteractionCard(
    interaction: interaction,
    schoolName: "Stanford University",
    coachName: "Coach Smith"
  )
  .padding()
}
