import SwiftUI

/// The coach detail interactions log — filterable + expandable (parity with the
/// web coach page's folded-in communication log). Replaces the old static
/// "Recent Interactions" list; the standalone communications screen is gone.
struct CoachInteractionsLogSection: View {
  @Bindable var viewModel: CoachDetailViewModel

  @State private var expandedIDs: Set<String> = []

  private var filtered: [Interaction] { viewModel.filteredInteractions }
  private var sentCount: Int { filtered.filter { $0.direction == .outbound }.count }
  private var receivedCount: Int { filtered.filter { $0.direction == .inbound }.count }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SectionHeader(title: "Interactions")
        Spacer()
        if viewModel.hasActiveFilters {
          Button("Clear") { viewModel.clearFilters() }
            .font(.footnote)
        }
      }

      if !viewModel.recentInteractions.isEmpty {
        filterBar
        summaryRow
      }

      if viewModel.recentInteractions.isEmpty {
        emptyState(String(localized: "No interactions yet"))
      } else if filtered.isEmpty {
        emptyState(String(localized: "No interactions match your filters"))
      } else {
        VStack(spacing: 0) {
          ForEach(filtered) { interaction in
            ExpandableInteractionRow(
              interaction: interaction,
              isExpanded: expandedIDs.contains(interaction.id),
              onToggle: { toggle(interaction.id) }
            )
            if interaction.id != filtered.last?.id {
              Divider().accessibilityHidden(true)
            }
          }
        }
      }
    }
  }

  @ViewBuilder private var filterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        filterMenu(
          title: viewModel.filterType?.displayName ?? String(localized: "Type"),
          isActive: viewModel.filterType != nil
        ) {
          Button(String(localized: "All types")) { viewModel.filterType = nil }
          ForEach(InteractionType.allCases, id: \.self) { type in
            Button(type.displayName) { viewModel.filterType = type }
          }
        }

        filterMenu(
          title: viewModel.filterDirection?.displayName ?? String(localized: "Direction"),
          isActive: viewModel.filterDirection != nil
        ) {
          Button(String(localized: "Both")) { viewModel.filterDirection = nil }
          ForEach(Direction.allCases, id: \.self) { direction in
            Button(direction.displayName) { viewModel.filterDirection = direction }
          }
        }

        filterMenu(
          title: viewModel.filterSentiment?.displayName ?? String(localized: "Sentiment"),
          isActive: viewModel.filterSentiment != nil
        ) {
          Button(String(localized: "All sentiments")) { viewModel.filterSentiment = nil }
          ForEach(Sentiment.allCases, id: \.self) { sentiment in
            Button(sentiment.displayName) { viewModel.filterSentiment = sentiment }
          }
        }

        filterMenu(
          title: windowLabel,
          isActive: viewModel.filterWindowDays != nil
        ) {
          Button(String(localized: "All time")) { viewModel.filterWindowDays = nil }
          Button(String(localized: "Last 7 days")) { viewModel.filterWindowDays = 7 }
          Button(String(localized: "Last 30 days")) { viewModel.filterWindowDays = 30 }
          Button(String(localized: "Last 90 days")) { viewModel.filterWindowDays = 90 }
          Button(String(localized: "Last 6 months")) { viewModel.filterWindowDays = 180 }
        }
      }
    }
  }

  private var windowLabel: String {
    switch viewModel.filterWindowDays {
    case 7: return String(localized: "Last 7 days")
    case 30: return String(localized: "Last 30 days")
    case 90: return String(localized: "Last 90 days")
    case 180: return String(localized: "Last 6 months")
    default: return String(localized: "Date range")
    }
  }

  @ViewBuilder
  private func filterMenu<Content: View>(
    title: String,
    isActive: Bool,
    @ViewBuilder content: () -> Content
  ) -> some View {
    Menu {
      content()
    } label: {
      HStack(spacing: 4) {
        Text(title).font(.footnote.weight(.medium))
        Image(systemName: "chevron.down").font(.caption2)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(isActive ? BadgeColor.blue.backgroundColor : Color(.systemGray6))
      .foregroundStyle(isActive ? BadgeColor.blue.foregroundColor : Color.primary)
      .clipShape(Capsule())
    }
  }

  @ViewBuilder private var summaryRow: some View {
    HStack(spacing: 8) {
      summaryTile(String(localized: "Shown"), "\(filtered.count)", .primary)
      summaryTile(String(localized: "Sent"), "\(sentCount)", BadgeColor.blue.foregroundColor)
      summaryTile(String(localized: "Received"), "\(receivedCount)", BadgeColor.emerald.foregroundColor)
    }
  }

  private func summaryTile(_ label: String, _ value: String, _ color: Color) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.headline).foregroundStyle(color)
      Text(label).font(.caption).foregroundStyle(Color.secondaryText)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  private func emptyState(_ text: String) -> some View {
    Text(text)
      .font(.body)
      .foregroundStyle(.secondary)
      .italic()
      .padding(.vertical, 8)
  }

  private func toggle(_ id: String) {
    if expandedIDs.contains(id) {
      expandedIDs.remove(id)
    } else {
      expandedIDs.insert(id)
    }
  }
}

/// A tappable interaction row that discloses subject/content/attachments.
private struct ExpandableInteractionRow: View {
  let interaction: Interaction
  let isExpanded: Bool
  let onToggle: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(action: onToggle) {
        HStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(interaction.type.tintColor.opacity(0.15))
              .frame(width: 36, height: 36)
            Image(systemName: interaction.type.iconName)
              .font(.system(size: 15))
              .foregroundStyle(interaction.type.tintColor)
          }
          .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(interaction.type.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
              Text(interaction.direction == .outbound ? String(localized: "Sent") : String(localized: "Received"))
                .font(.caption2.weight(.medium))
                .foregroundStyle(interaction.direction.badgeColor.foregroundColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(interaction.direction.badgeColor.backgroundColor)
                .clipShape(Capsule())
            }
            if let subject = interaction.subject, !subject.isEmpty {
              Text(subject)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .lineLimit(1)
            }
          }

          Spacer()

          VStack(alignment: .trailing, spacing: 4) {
            Text(interaction.displayDate, style: .date)
              .font(.caption)
              .foregroundStyle(Color.secondaryText)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption2)
              .foregroundStyle(Color.secondaryText)
              .accessibilityHidden(true)
          }
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        if let content = interaction.content, !content.isEmpty {
          Text(content)
            .font(.footnote)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text("No message content")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .italic()
        }

        if let sentiment = interaction.sentiment {
          Text(sentiment.displayName)
            .font(.caption.weight(.medium))
            .foregroundStyle(sentiment.badgeColor.foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(sentiment.badgeColor.backgroundColor)
            .clipShape(Capsule())
        }

        if interaction.hasAttachments {
          Label("\(interaction.attachmentCount) attachment\(interaction.attachmentCount == 1 ? "" : "s")", systemImage: "paperclip")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      }
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .contain)
  }
}
