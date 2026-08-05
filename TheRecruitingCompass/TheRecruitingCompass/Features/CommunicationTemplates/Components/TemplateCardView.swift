import SwiftUI

struct TemplateCardView: View {
  let template: CommunicationTemplate
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text(template.name)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)

          HStack(spacing: 8) {
            TypeBadgeView(type: template.type)

            Text(template.formattedDate)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        Button {
          onEdit()
        } label: {
          Image(systemName: "pencil")
            .font(.body)
            .foregroundStyle(Color.accentBlue)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(editAccessibilityLabel)
        .accessibilityIdentifier("template.editButton.\(template.id)")
      }

      Text(template.bodyPreview)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(3)
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .contentShape(Rectangle())
    .onTapGesture { onEdit() }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(cardAccessibilityLabel)
    .accessibilityHint("Double tap to edit")
    .accessibilityIdentifier("template.card.\(template.id)")
  }

  var cardAccessibilityLabel: String {
    String(localized: "\(template.name), \(template.typeDisplayName) template, Created \(template.formattedDate)")
  }

  var editAccessibilityLabel: String {
    String(localized: "Edit \(template.name) template")
  }
}
