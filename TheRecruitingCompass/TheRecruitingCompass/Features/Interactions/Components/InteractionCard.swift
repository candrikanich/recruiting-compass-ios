import SwiftUI

struct InteractionCard: View {
  let interaction: Interaction
  let schoolName: String?
  let coachName: String?
  let onDelete: (() -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header: Type icon, badges
      HStack(spacing: 12) {
        // Type icon
        ZStack {
          Circle()
            .fill(interaction.type.iconColor.opacity(0.15))
            .frame(width: iconSize, height: iconSize)

          Image(systemName: interaction.type.iconName)
            .font(.system(size: iconImageSize))
            .foregroundColor(interaction.type.iconColor)
        }
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(interaction.type.displayName)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.primary)

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
          .foregroundColor(.primary)
      }

      // School and Coach
      if schoolName != nil || coachName != nil {
        HStack(spacing: 4) {
          if let schoolName {
            Text(schoolName)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }

          if schoolName != nil && coachName != nil {
            Text("•")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }

          if let coachName {
            Text(coachName)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
        .lineLimit(1)
      }

      // Content preview
      if let content = interaction.content, !content.isEmpty {
        Text(content)
          .font(.body)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }

      // Date
      HStack(spacing: 4) {
        Image(systemName: "calendar")
          .font(.caption)
          .foregroundColor(.secondary)
          .accessibilityHidden(true)

        Text(DateFormatting.mediumDateShortTime(interaction.displayDate))
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint("Tap to view details")
  }

  // MARK: - Computed Properties

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 48 : 40
  }

  private var iconImageSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 22 : 18
  }

  private var accessibilityLabel: String {
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
      .foregroundColor(direction.badgeColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(direction.badgeColor.opacity(0.1))
      .cornerRadius(6)
  }
}

struct SentimentBadge: View {
  let sentiment: Sentiment

  var body: some View {
    Text(sentiment.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundColor(sentiment.badgeColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(sentiment.badgeColor.opacity(0.1))
      .cornerRadius(6)
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
    .foregroundColor(.secondary)
    .accessibilityLabel("\(count) attachment\(count == 1 ? "" : "s")")
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
    coachName: "Coach Smith",
    onDelete: nil
  )
  .padding()
}
