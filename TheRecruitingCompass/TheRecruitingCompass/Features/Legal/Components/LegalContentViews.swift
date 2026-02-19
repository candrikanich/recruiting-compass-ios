import SwiftUI
import UIKit

// MARK: - Shared legal document content views (Terms of Service, Privacy Policy)

struct LegalSectionHeader: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.headline)
      .foregroundColor(Color.darkSlate)
      .accessibilityAddTraits(.isHeader)
  }
}

struct LegalSubsectionHeader: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.subheadline.weight(.semibold))
      .foregroundColor(Color.darkSlate)
      .accessibilityAddTraits(.isHeader)
  }
}

struct LegalBodyText: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.body)
      .foregroundColor(Color.secondaryText)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct LegalBulletList: View {
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(items, id: \.self) { item in
        HStack(alignment: .top, spacing: 8) {
          Text("•")
            .font(.body)
            .foregroundColor(Color.secondaryText)
          Text(item)
            .font(.body)
            .foregroundColor(Color.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

struct LegalEmailLink: View {
  let email: String
  @State private var showMailUnavailableAlert = false

  var body: some View {
    Group {
      if let url = URL(string: "mailto:\(email)") {
        Button {
          Task { @MainActor in
            let opened = await UIApplication.shared.open(url)
            if !opened {
              showMailUnavailableAlert = true
            }
          }
        } label: {
          Text(email)
        }
        .font(.body.weight(.medium))
        .foregroundColor(Color.accentBlue)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Email \(email.replacingOccurrences(of: "@", with: " at ").replacingOccurrences(of: ".", with: " dot "))")
        .accessibilityHint("Opens Mail app")
        .alert("Email not available on this device", isPresented: $showMailUnavailableAlert) {
          Button("OK", role: .cancel) {}
        }
      } else {
        Text(email)
          .font(.body)
          .foregroundColor(Color.accentBlue)
      }
    }
  }
}
