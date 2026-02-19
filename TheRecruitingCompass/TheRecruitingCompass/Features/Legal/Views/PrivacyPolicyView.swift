import SwiftUI

struct PrivacyPolicyView: View {
  @State private var viewModel = PrivacyPolicyViewModel()
  @Environment(\.dismiss) var dismiss

  private let contactBoxBackground = Color(hex: "F3F4F6")
  private let sectionSpacing: CGFloat = 16
  private let padding: CGFloat = 20

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.isLoading {
          loadingView
        } else {
          contentView
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.white)
      .navigationTitle("Privacy Policy")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Back") { dismiss() }
            .foregroundColor(Color.darkSlate)
            .accessibilityLabel("Back")
            .accessibilityHint("Dismiss Privacy Policy")
        }
      }
      .task { await viewModel.loadPolicy() }
    }
  }

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Loading Privacy Policy...")
        .font(.subheadline)
        .foregroundColor(Color.secondaryText)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Loading Privacy Policy")
  }

  private var contentView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if !viewModel.lastUpdated.isEmpty {
          Text("Last Updated: \(viewModel.lastUpdated)")
            .font(.caption)
            .foregroundColor(Color.secondaryText)
        }

        section1Introduction
        section2InformationWeCollect
        section3HowWeUse
        section4Sharing
        section5DataSecurity
        section6Retention
        section7PrivacyRights
        section8Cookies
        section9ThirdPartyLinks
        section10ChildrenPrivacy
        section11Changes
        section12ContactUs
      }
      .padding(padding)
    }
  }

  // MARK: - Section 1: Introduction

  private var section1Introduction: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("1. Introduction")

      bodyText(
        "Recruiting Compass (\"we,\" \"us,\" \"our,\" or \"Company\") is committed to protecting your privacy. " +
          "This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you " +
          "visit our website and use our services."
      )
      bodyText(
        "Please read this privacy policy carefully. If you do not agree with our policies and practices, please do not use our Service."
      )
    }
  }

  // MARK: - Section 2: Information We Collect

  private var section2InformationWeCollect: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("2. Information We Collect")

      bodyText("We may collect information about you in a variety of ways:")

      subsectionHeader("Information You Provide")
      bulletList([
        "Registration Information: Name, email address, password, phone number, and role (parent or player)",
        "Profile Information: Profile photo, biographical information, preferences, and school-related data",
        "Communication Data: Messages, notes, and communications you create or store within the Service",
        "Preference Data: School preferences, location preferences, and other customization settings",
      ])

      subsectionHeader("Automatically Collected Information")
      bulletList([
        "Log Data: IP address, browser type, pages visited, and time and date stamps",
        "Device Information: Device type, operating system, and unique device identifiers",
        "Usage Analytics: How you interact with our Service, features you use, and actions you take",
        "Cookies: Small data files stored on your device to enhance your experience",
      ])
    }
  }

  // MARK: - Section 3: How We Use Your Information

  private var section3HowWeUse: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("3. How We Use Your Information")
      bodyText("We use the information we collect for various purposes:")
      bulletList([
        "To create and maintain your account",
        "To provide, maintain, and improve the Service",
        "To send administrative information and updates",
        "To respond to your inquiries and requests",
        "To analyze usage patterns and improve our offerings",
        "To comply with legal obligations",
        "To prevent fraud and enhance security",
        "To send marketing communications (with your consent)",
      ])
    }
  }

  // MARK: - Section 4: Sharing Your Information

  private var section4Sharing: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("4. Sharing Your Information")
      bodyText(
        "We do not sell, trade, or rent your personal information to third parties. We may share information in the following circumstances:"
      )
      bulletList([
        "Service Providers: Third-party vendors who assist in operating our Service, subject to confidentiality agreements",
        "Legal Requirements: When required by law, court order, or government request",
        "Business Transfers: In connection with a merger, acquisition, or sale of assets",
        "With Your Consent: When you explicitly authorize us to share your information",
      ])
    }
  }

  // MARK: - Section 5: Data Security

  private var section5DataSecurity: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("5. Data Security")
      bodyText(
        "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the Internet or electronic storage is completely secure. We cannot guarantee absolute security of your information."
      )
    }
  }

  // MARK: - Section 6: Retention of Information

  private var section6Retention: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("6. Retention of Information")
      bodyText(
        "We retain your personal information for as long as necessary to provide the Service and fulfill the purposes outlined in this Privacy Policy. You may request deletion of your account and associated data at any time, subject to legal retention requirements."
      )
    }
  }

  // MARK: - Section 7: Your Privacy Rights

  private var section7PrivacyRights: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("7. Your Privacy Rights")
      bodyText("Depending on your location, you may have the right to:")
      bulletList([
        "Access the personal information we hold about you",
        "Correct inaccurate or incomplete information",
        "Request deletion of your information",
        "Opt-out of certain data processing activities",
        "Request a portable copy of your data",
        "Withdraw consent at any time",
      ])
      bodyText("To exercise these rights, please contact us at privacy@recruitingcompass.com.")
    }
  }

  // MARK: - Section 8: Cookies and Tracking Technologies

  private var section8Cookies: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("8. Cookies and Tracking Technologies")
      bodyText(
        "We use cookies and similar tracking technologies to enhance your experience. Most web browsers allow you to control cookies through their settings. Disabling cookies may affect the functionality of our Service."
      )
    }
  }

  // MARK: - Section 9: Third-Party Links

  private var section9ThirdPartyLinks: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("9. Third-Party Links")
      bodyText(
        "Our Service may contain links to third-party websites. We are not responsible for the privacy practices of those sites. We encourage you to review the privacy policies of any third-party sites before providing your information."
      )
    }
  }

  // MARK: - Section 10: Children's Privacy

  private var section10ChildrenPrivacy: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("10. Children's Privacy")
      bodyText(
        "Our Service is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected information from a child under 13, we will take steps to delete such information promptly."
      )
    }
  }

  // MARK: - Section 11: Changes to This Privacy Policy

  private var section11Changes: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("11. Changes to This Privacy Policy")
      bodyText(
        "We may update this Privacy Policy from time to time to reflect changes in our practices or for other operational, legal, or regulatory reasons. We will notify you of material changes by updating the \"Last Updated\" date and, in some cases, by providing additional notice."
      )
    }
  }

  // MARK: - Section 12: Contact Us

  private var section12ContactUs: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      sectionHeader("12. Contact Us")
      bodyText(
        "If you have questions about this Privacy Policy or our privacy practices, please contact us at:"
      )

      VStack(alignment: .leading, spacing: 8) {
        Text("Recruiting Compass")
          .font(.headline)
          .foregroundColor(Color.darkSlate)

        HStack(spacing: 4) {
          Text("Email:")
            .font(.body)
            .foregroundColor(Color.secondaryText)
          emailLink("privacy@recruitingcompass.com")
        }

        HStack(spacing: 4) {
          Text("Support:")
            .font(.body)
            .foregroundColor(Color.secondaryText)
          emailLink("support@recruitingcompass.com")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(contactBoxBackground)
      .cornerRadius(12)
    }
  }

  // MARK: - Helpers

  private func sectionHeader(_ text: String) -> some View {
    Text(text)
      .font(.headline)
      .foregroundColor(Color.darkSlate)
      .accessibilityAddTraits(.isHeader)
  }

  private func subsectionHeader(_ text: String) -> some View {
    Text(text)
      .font(.subheadline.weight(.semibold))
      .foregroundColor(Color.darkSlate)
      .accessibilityAddTraits(.isHeader)
  }

  private func bodyText(_ text: String) -> some View {
    Text(text)
      .font(.body)
      .foregroundColor(Color.secondaryText)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func bulletList(_ items: [String]) -> some View {
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

  @ViewBuilder
  private func emailLink(_ email: String) -> some View {
    if let url = URL(string: "mailto:\(email)") {
      Link(email, destination: url)
        .font(.body.weight(.medium))
        .foregroundColor(Color.accentBlue)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Email \(email.replacingOccurrences(of: "@", with: " at ").replacingOccurrences(of: ".", with: " dot "))")
        .accessibilityHint("Opens Mail app")
    } else {
      Text(email)
        .font(.body)
        .foregroundColor(Color.accentBlue)
    }
  }
}

#Preview {
  PrivacyPolicyView()
}
