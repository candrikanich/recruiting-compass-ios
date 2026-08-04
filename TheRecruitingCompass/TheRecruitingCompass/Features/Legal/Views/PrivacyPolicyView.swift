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
              .accessibilityLabel("Back")
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
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
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

  @ViewBuilder
  private var section1Introduction: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "1. Introduction")

      LegalBodyText(text:
        "The Recruiting Compass (\"we,\" \"us,\" \"our,\" or \"Company\") is committed to protecting your privacy. " +
          "This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you " +
          "visit our website and use our services."
      )
      LegalBodyText(text:
        "Please read this privacy policy carefully. If you do not agree with our policies and practices, please do not use our Service."
      )
    }
  }

  // MARK: - Section 2: Information We Collect

  @ViewBuilder
  private var section2InformationWeCollect: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "2. Information We Collect")

      LegalBodyText(text: "We may collect information about you in a variety of ways:")

      LegalSubsectionHeader(text: "Information You Provide")
      LegalBulletList(items: [
        "Registration Information: Name, email address, password, phone number, and role (parent or player)",
        "Profile Information: Profile photo, biographical information, preferences, and school-related data",
        "Communication Data: Messages, notes, and communications you create or store within the Service",
        "Preference Data: School preferences, location preferences, and other customization settings"
      ])

      LegalSubsectionHeader(text: "Automatically Collected Information")
      LegalBulletList(items: [
        "Log Data: IP address, browser type, pages visited, and time and date stamps",
        "Device Information: Device type, operating system, and unique device identifiers",
        "Usage Analytics: How you interact with our Service, features you use, and actions you take",
        "Cookies: Small data files stored on your device to enhance your experience"
      ])
    }
  }

  // MARK: - Section 3: How We Use Your Information

  @ViewBuilder
  private var section3HowWeUse: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "3. How We Use Your Information")
      LegalBodyText(text: "We use the information we collect for various purposes:")
      LegalBulletList(items: [
        "To create and maintain your account",
        "To provide, maintain, and improve the Service",
        "To send administrative information and updates",
        "To respond to your inquiries and requests",
        "To analyze usage patterns and improve our offerings",
        "To comply with legal obligations",
        "To prevent fraud and enhance security",
        "To send marketing communications (with your consent)"
      ])
    }
  }

  // MARK: - Section 4: Sharing Your Information

  @ViewBuilder
  private var section4Sharing: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "4. Sharing Your Information")
      LegalBodyText(text:
        "We do not sell, trade, or rent your personal information to third parties. We may share information in the following circumstances:"
      )
      LegalBulletList(items: [
        "Service Providers: Third-party vendors who assist in operating our Service, subject to confidentiality agreements",
        "Legal Requirements: When required by law, court order, or government request",
        "Business Transfers: In connection with a merger, acquisition, or sale of assets",
        "With Your Consent: When you explicitly authorize us to share your information"
      ])
    }
  }

  // MARK: - Section 5: Data Security

  @ViewBuilder
  private var section5DataSecurity: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "5. Data Security")
      LegalBodyText(text:
        "We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the Internet or electronic storage is completely secure. We cannot guarantee absolute security of your information."
      )
    }
  }

  // MARK: - Section 6: Retention of Information

  @ViewBuilder
  private var section6Retention: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "6. Retention of Information")
      LegalBodyText(text:
        "We retain your personal information for as long as necessary to provide the Service and fulfill the purposes outlined in this Privacy Policy. You may request deletion of your account and associated data at any time, subject to legal retention requirements."
      )
    }
  }

  // MARK: - Section 7: Your Privacy Rights

  @ViewBuilder
  private var section7PrivacyRights: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "7. Your Privacy Rights")
      LegalBodyText(text: "Depending on your location, you may have the right to:")
      LegalBulletList(items: [
        "Access the personal information we hold about you",
        "Correct inaccurate or incomplete information",
        "Request deletion of your information",
        "Opt-out of certain data processing activities",
        "Request a portable copy of your data",
        "Withdraw consent at any time"
      ])
      LegalBodyText(text: "To exercise these rights, please contact us at privacy@recruitingcompass.com.")
    }
  }

  // MARK: - Section 8: Cookies and Tracking Technologies

  @ViewBuilder
  private var section8Cookies: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "8. Cookies and Tracking Technologies")
      LegalBodyText(text:
        "We use cookies and similar tracking technologies to enhance your experience. Most web browsers allow you to control cookies through their settings. Disabling cookies may affect the functionality of our Service."
      )
    }
  }

  // MARK: - Section 9: Third-Party Links

  @ViewBuilder
  private var section9ThirdPartyLinks: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "9. Third-Party Links")
      LegalBodyText(text:
        "Our Service may contain links to third-party websites. We are not responsible for the privacy practices of those sites. We encourage you to review the privacy policies of any third-party sites before providing your information."
      )
    }
  }

  // MARK: - Section 10: Children's Privacy

  @ViewBuilder
  private var section10ChildrenPrivacy: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "10. Children's Privacy")
      LegalBodyText(text:
        "Our Service is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected information from a child under 13, we will take steps to delete such information promptly."
      )
    }
  }

  // MARK: - Section 11: Changes to This Privacy Policy

  @ViewBuilder
  private var section11Changes: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "11. Changes to This Privacy Policy")
      LegalBodyText(text:
        "We may update this Privacy Policy from time to time to reflect changes in our practices or for other operational, legal, or regulatory reasons. We will notify you of material changes by updating the \"Last Updated\" date and, in some cases, by providing additional notice."
      )
    }
  }

  // MARK: - Section 12: Contact Us

  @ViewBuilder
  private var section12ContactUs: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "12. Contact Us")
      LegalBodyText(text:
        "If you have questions about this Privacy Policy or our privacy practices, please contact us at:"
      )

      VStack(alignment: .leading, spacing: 8) {
        Text("The Recruiting Compass")
          .font(.headline)
          .foregroundStyle(Color.darkSlate)

        HStack(spacing: 4) {
          Text("Email:")
            .font(.body)
            .foregroundStyle(Color.secondaryText)
          LegalEmailLink(email: "privacy@recruitingcompass.com")
        }

        HStack(spacing: 4) {
          Text("Support:")
            .font(.body)
            .foregroundStyle(Color.secondaryText)
          LegalEmailLink(email: "support@recruitingcompass.com")
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(contactBoxBackground)
      .clipShape(.rect(cornerRadius: 12))
    }
  }

}

#Preview {
  PrivacyPolicyView()
}
