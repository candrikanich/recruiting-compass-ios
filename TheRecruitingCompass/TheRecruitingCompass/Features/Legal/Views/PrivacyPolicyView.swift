import SwiftUI

struct PrivacyPolicyView: View {
  @State private var viewModel = PrivacyPolicyViewModel()
  @Environment(\.dismiss) var dismiss

  private let contactBoxBackground = Color.Surface.muted
  private let sectionSpacing: CGFloat = 16
  private let padding: CGFloat = 20

  var body: some View {
    NavigationStack {
      contentView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Surface.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Back") { dismiss() }
              .foregroundStyle(Color.darkSlate)
              .accessibilityLabel(String(localized: "Back"))
              .accessibilityHint("Dismiss Privacy Policy")
          }
        }
    }
  }

  @ViewBuilder
  private var contentView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if !viewModel.lastUpdated.isEmpty {
          Text("Last Updated: \(viewModel.lastUpdated)")
            .font(.brand(.caption))
            .foregroundStyle(Color.secondaryText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }

        ForEach(PrivacyPolicyContent.sections) { section in
          sectionView(section)
        }
        contactBox
      }
      .padding(padding)
    }
  }

  private func sectionView(_ section: PrivacyPolicyContent.Section) -> some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: section.heading)
      ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
        switch block {
        case .body(let text): LegalBodyText(text: text)
        case .subheading(let text): LegalSubsectionHeader(text: text)
        case .bullets(let items): LegalBulletList(items: items)
        }
      }
    }
  }

  @ViewBuilder
  private var contactBox: some View {
    let contact = PrivacyPolicyContent.contact
    VStack(alignment: .leading, spacing: 8) {
      Text(contact.name)
        .font(.brand(.headline))
        .foregroundStyle(Color.darkSlate)

      Text(contact.address)
        .font(.brand(.body))
        .foregroundStyle(Color.secondaryText)

      HStack(spacing: 4) {
        Text("Privacy inquiries:")
          .font(.brand(.body))
          .foregroundStyle(Color.secondaryText)
        LegalEmailLink(email: contact.privacyEmail)
      }

      HStack(spacing: 4) {
        Text("General support:")
          .font(.brand(.body))
          .foregroundStyle(Color.secondaryText)
        LegalEmailLink(email: contact.supportEmail)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(contactBoxBackground)
    .clipShape(.rect(cornerRadius: 12))
  }
}

#Preview {
  PrivacyPolicyView()
}
