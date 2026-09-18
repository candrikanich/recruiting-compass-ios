import SwiftUI

struct ForwardCoachEmailsCard: View {
  let address: String
  let onCopy: () -> Void

  var body: some View {
    VStack(spacing: FamilyConstants.Spacing.medium) {
      VStack(spacing: FamilyConstants.Spacing.medium) {
        Text("Forward Coach Emails")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("Forward or CC emails from coaches to this address to automatically draft an interaction log entry for your family.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: FamilyConstants.Spacing.small) {
          Text(address)
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .lineLimit(1)
            .truncationMode(.middle)

          Spacer()

          Button(action: onCopy) {
            Label("Copy", systemImage: "doc.on.doc")
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Copy forwarding address to clipboard"))
        }
        .padding(FamilyConstants.Spacing.small)
        .background(Color.gray.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(String(localized: "Forward Coach Emails, forwarding address \(address)"))

      NavigationLink {
        InboundDraftsView()
      } label: {
        HStack(spacing: 4) {
          Text("Review forwarded coach emails")
          Image(systemName: "arrow.right")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(.subheadline.weight(.medium))
    }
    .padding(FamilyConstants.Spacing.medium)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}
