import SwiftUI

struct ActivityEventItem: View {
  let event: ActivityEvent
  let compact: Bool

  @Environment(\.sizeCategory) private var sizeCategory

  init(event: ActivityEvent, compact: Bool = false) {
    self.event = event
    self.compact = compact
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(iconBackgroundColor.opacity(0.15))
          .frame(width: iconSize, height: iconSize)

        Image(systemName: event.icon)
          .font(compact ? .caption : .body)
          .foregroundStyle(iconBackgroundColor)
      }
      .accessibilityHidden(true)

      // Content
      VStack(alignment: .leading, spacing: compact ? 2 : 4) {
        Text(event.title)
          .font(compact ? .subheadline : .headline)
          .fontWeight(.medium)
          .foregroundStyle(.primary)
          .lineLimit(1)

        if !event.description.isEmpty {
          Text(event.description)
            .font(compact ? .caption : .subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer()

      // Time + chevron
      VStack(alignment: .trailing, spacing: 4) {
        Text(event.timestamp, format: .relative(presentation: .named))
          .font(.caption)
          .foregroundStyle(Color.tertiaryText)

        if event.isClickable {
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.iconGray)
            .accessibilityHidden(true)
        }
      }
    }
    .padding(compact ? 12 : 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .frame(minHeight: 44)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(event.isClickable ? .isButton : [])
    .accessibilityHint(event.isClickable ? "Tap to view details" : "")
    .accessibilityIdentifier("activity-event-\(event.id)")
  }

  // MARK: - Private

  private var iconSize: CGFloat {
    if compact {
      return sizeCategory.isAccessibilityCategory ? 36 : 32
    }
    return sizeCategory.isAccessibilityCategory ? 48 : 40
  }

  private var iconBackgroundColor: Color {
    switch event.type {
    case .interaction: return .accentBlue
    case .schoolStatusChange: return .primaryGreen
    case .documentUpload: return .amberGold
    }
  }

  var accessibilityLabel: String {
    let relativeTime = RelativeDateTimeFormatter().localizedString(for: event.timestamp, relativeTo: Date())
    var parts: [String] = []
    parts.append(event.type.label)
    parts.append(event.title)
    if !event.description.isEmpty {
      parts.append(event.description)
    }
    parts.append(relativeTime)
    return parts.joined(separator: ", ")
  }
}

#Preview {
  VStack(spacing: 12) {
    ActivityEventItem(
      event: ActivityEvent(
        id: "interaction-1",
        type: .interaction,
        timestamp: Date().addingTimeInterval(-7200),
        title: "Email with Arizona State",
        description: "Discussed camp schedule and upcoming visit dates",
        icon: "envelope.fill",
        entityType: "school",
        entityId: "school1",
        entityName: "Arizona State",
        isClickable: true,
        clickUrl: "/schools/school1"
      )
    )

    ActivityEventItem(
      event: ActivityEvent(
        id: "status-1",
        type: .schoolStatusChange,
        timestamp: Date().addingTimeInterval(-86400),
        title: "Stanford - Interested",
        description: "Status changed to Interested",
        icon: "mappin.circle.fill",
        entityType: "school",
        entityId: "school2",
        entityName: "Stanford",
        isClickable: true,
        clickUrl: "/schools/school2"
      )
    )

    ActivityEventItem(
      event: ActivityEvent(
        id: "doc-1",
        type: .documentUpload,
        timestamp: Date().addingTimeInterval(-172800),
        title: "Uploaded: Transcript",
        description: "New document uploaded",
        icon: "doc.fill",
        entityType: "document",
        entityId: "doc1",
        entityName: "Transcript",
        isClickable: false,
        clickUrl: nil
      ),
      compact: true
    )
  }
  .padding()
}
