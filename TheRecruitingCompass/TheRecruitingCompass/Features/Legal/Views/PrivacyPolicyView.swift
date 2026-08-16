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
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }

        section1Introduction
        section2InformationWeCollect
        section3HowWeUse
        section4ThirdPartyDataSources
        section5Sharing
        section6DataSecurity
        section7Retention
        section8PrivacyRights
        section9Cookies
        section10ChildrenPrivacy
        section11ThirdPartyLinks
        section12Changes
        section13ContactUs
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
        "Please read this Privacy Policy carefully. If you do not agree with our policies and practices, please do not use our Service. " +
          "This Policy is incorporated by reference into our Terms and Conditions."
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
        "Registration Information: Name, email address, password (stored as a hashed value — never in plaintext), date of birth (used to verify age eligibility), and role (parent or player)",
        "Profile Information: Profile photo, graduation year, sport, position, GPA, standardized test scores, athletic stats, and recruiting preferences",
        "Recruiting Activity: Schools and college programs you track, coach contact information you enter, and interaction notes and communication logs you create",
        "Family Unit Data: Email addresses of family members you invite to join your family unit, which are retained until the invitation is accepted, declined, or expires",
        "Preference Data: Location preferences, school type preferences, and other customization settings"
      ])

      LegalSubsectionHeader(text: "Sensitive Information")
      LegalBodyText(text:
        "Some of the profile information we collect — such as a minor's date of birth, academic records (GPA, standardized test scores), and " +
          "graduation year — may be considered sensitive under certain state privacy laws. We use this information solely to operate the Service " +
          "(for example, to enforce age eligibility and calculate Fit Scores) and we never sell it or use it for targeted advertising. We are not a " +
          "school or educational agency, and the academic information you enter is not a FERPA \"education record\"; it is data you voluntarily provide and control."
      )

      LegalSubsectionHeader(text: "Data We Do Not Collect")
      LegalBulletList(items: [
        "Health, medical, or injury information",
        "Financial data or payment card information (no payment processor is currently in use)",
        "Social Security numbers or government-issued identification numbers"
      ])

      LegalSubsectionHeader(text: "Automatically Collected Information")
      LegalBulletList(items: [
        "Log Data: IP address, browser type, pages visited, and time and date stamps",
        "Device Information: Device type, operating system, and unique device identifiers",
        "Usage Analytics: How you interact with our Service, features you use, and actions you take",
        "Cookies: Small data files stored on your device to maintain your session and enhance your experience"
      ])
    }
  }

  // MARK: - Section 3: How We Use Your Information

  @ViewBuilder
  private var section3HowWeUse: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "3. How We Use Your Information")
      LegalBodyText(text: "We use the information we collect for the following purposes:")
      LegalBulletList(items: [
        "To create and maintain your account",
        "To provide, maintain, and improve the Service",
        "To calculate your Fit Score — an algorithmic estimate of school compatibility based on your profile data and publicly available school information",
        "To send transactional emails (account confirmations, family invitations, and password resets)",
        "To send product updates, recruiting tips, and promotional information about paid features — which you may opt out of at any time via the unsubscribe link in any such email or your account settings",
        "To respond to your inquiries and support requests",
        "To analyze usage patterns and improve our offerings",
        "To comply with legal obligations",
        "To prevent fraud and enhance security"
      ])
    }
  }

  // MARK: - Section 4: Third-Party Data Sources

  @ViewBuilder
  private var section4ThirdPartyDataSources: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "4. Third-Party Data Sources")
      LegalBodyText(text:
        "School and program information displayed in the Service may be sourced from the U.S. Department of Education College Scorecard API and other " +
          "publicly available sources. We use this data to provide reference information about colleges and athletic programs."
      )
      LegalBodyText(text:
        "We do not sell or share your personal information with third parties for advertising or marketing purposes."
      )
    }
  }

  // MARK: - Section 5: Sharing Your Information

  @ViewBuilder
  private var section5Sharing: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "5. Sharing Your Information")
      LegalBodyText(text:
        "We do not sell, trade, or rent your personal information to third parties. We may share information in the following circumstances:"
      )
      LegalBulletList(items: [
        "Service Providers: Third-party vendors who assist in operating our Service (e.g., hosting, email delivery), subject to confidentiality obligations",
        "Family Unit Members: If you are part of a family unit, limited profile information is visible to other members of that unit",
        "Legal Requirements: When required by law, court order, or government request",
        "Business Transfers: In connection with a merger, acquisition, or sale of assets, with appropriate notice to users",
        "With Your Consent: When you explicitly authorize us to share your information"
      ])
    }
  }

  // MARK: - Section 6: Data Security

  @ViewBuilder
  private var section6DataSecurity: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "6. Data Security")
      LegalBodyText(text:
        "We implement appropriate technical and organizational measures to protect your personal information, including:"
      )
      LegalBulletList(items: [
        "Encryption of data in transit (TLS/HTTPS)",
        "Encryption of data at rest",
        "Row-level security policies enforcing data isolation between accounts",
        "Passwords stored exclusively as hashed values — never in plaintext"
      ])
      LegalBodyText(text:
        "However, no method of transmission over the Internet or electronic storage is completely secure. We cannot guarantee absolute security of your information."
      )
    }
  }

  // MARK: - Section 7: Data Retention

  @ViewBuilder
  private var section7Retention: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "7. Data Retention")
      LegalBodyText(text: "We retain your data as follows:")
      LegalBulletList(items: [
        "Active accounts: Data is retained for as long as your account is active",
        "Pending invitations: Invitation email addresses are retained until the invitation is accepted, declined, or expires (invitations expire after 30 days)",
        "Deleted accounts: Following an account deletion request, your personal data is purged within 30 days. You may cancel a deletion request within that 30-day window.",
        "Audit logs: Security- and account-related audit logs are retained for up to one year for fraud prevention and legal compliance purposes"
      ])
    }
  }

  // MARK: - Section 8: Your Privacy Rights

  @ViewBuilder
  private var section8PrivacyRights: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "8. Your Privacy Rights")
      LegalBodyText(text: "Depending on your location, you may have the right to:")
      LegalBulletList(items: [
        "Access the personal information we hold about you",
        "Correct inaccurate or incomplete information",
        "Request deletion of your information",
        "Opt out of certain data processing activities",
        "Request a portable copy of your data",
        "Withdraw consent at any time"
      ])

      LegalSubsectionHeader(text: "California Residents (CCPA)")
      LegalBodyText(text:
        "If you are a California resident, you have the following additional rights under the California Consumer Privacy Act:"
      )
      LegalBulletList(items: [
        "Right to Know: You may request disclosure of the categories and specific pieces of personal information we have collected about you",
        "Right to Delete: You may request deletion of your personal information, subject to certain exceptions",
        "Right to Opt Out of Sale: We do not sell your personal information",
        "Right to Non-Discrimination: We will not discriminate against you for exercising your CCPA rights"
      ])

      LegalSubsectionHeader(text: "Residents of Other States")
      LegalBodyText(text:
        "If you reside in a state with a comprehensive consumer privacy law (for example, Virginia, Colorado, Connecticut, Texas, Oregon, or Utah), " +
          "you may have rights similar to those above — including the right to access, correct, delete, and obtain a portable copy of your personal " +
          "data, and to opt out of the sale of your personal data, targeted advertising, and certain profiling. We do not sell personal data or use it " +
          "for targeted advertising or profiling in furtherance of decisions that produce legal or similarly significant effects."
      )

      LegalSubsectionHeader(text: "Minors")
      LegalBodyText(text:
        "For any user we know to be a minor (under 18), we do not sell their personal data, share it for cross-context behavioral advertising, or use it " +
          "for targeted advertising or profiling. We limit our collection and use of a minor's data to what is reasonably necessary to provide the Service."
      )

      LegalSubsectionHeader(text: "Global Privacy Control (GPC)")
      LegalBodyText(text:
        "We honor the Global Privacy Control (GPC) browser signal. If your browser or extension sends a GPC signal, we treat it as a valid request to " +
          "opt out of any sale or sharing of your personal data and to disable non-essential analytics for that browser."
      )

      LegalBodyText(text:
        "You can export a portable copy of your data and delete your account directly from your account settings (Data & Privacy). To exercise any " +
          "other right, please contact us at privacy@therecruitingcompass.com."
      )
    }
  }

  // MARK: - Section 9: Cookies and Tracking Technologies

  @ViewBuilder
  private var section9Cookies: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "9. Cookies and Tracking Technologies")
      LegalBodyText(text:
        "We use cookies and similar tracking technologies to maintain your session and enhance your experience. Most web browsers allow you to control " +
          "cookies through their settings. Disabling cookies may affect the functionality of our Service."
      )
      LegalBodyText(text:
        "We use the following third-party providers to operate and improve the Service: Sentry (error monitoring), PostHog (product analytics), and " +
          "Vercel Analytics and Speed Insights (performance measurement). These providers process usage and device data on our behalf and are not " +
          "permitted to use it for their own purposes."
      )
    }
  }

  // MARK: - Section 10: Children's Privacy (COPPA)

  @ViewBuilder
  private var section10ChildrenPrivacy: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "10. Children's Privacy (COPPA)")
      LegalBodyText(text:
        "The Service is not directed to children under the age of 13. We collect date of birth at registration to enforce this restriction and do not " +
          "knowingly create accounts for anyone under 13."
      )
      LegalBodyText(text:
        "Family unit accounts may include athletes between the ages of 13 and 17. Parents and guardians are responsible for supervising their minor's use of the Service."
      )
      LegalBodyText(text:
        "If you are a parent or guardian and believe your child under 13 has registered, or if you wish to request deletion of any data collected from a " +
          "minor in error, please contact us at privacy@therecruitingcompass.com."
      )
    }
  }

  // MARK: - Section 11: Third-Party Links

  @ViewBuilder
  private var section11ThirdPartyLinks: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "11. Third-Party Links")
      LegalBodyText(text:
        "Our Service may contain links to third-party websites. We are not responsible for the privacy practices of those sites. We encourage you to " +
          "review the privacy policies of any third-party sites before providing your information."
      )
    }
  }

  // MARK: - Section 12: Changes to This Privacy Policy

  @ViewBuilder
  private var section12Changes: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "12. Changes to This Privacy Policy")
      LegalBodyText(text:
        "We may update this Privacy Policy from time to time. For material changes — including changes to how we collect, use, or share your personal " +
          "information — we will provide at least 14 days' advance notice via an in-app notification and, where feasible, email. Your continued use of " +
          "the Service after the effective date of any change constitutes your acceptance of the updated Policy."
      )
    }
  }

  // MARK: - Section 13: Contact Us

  @ViewBuilder
  private var section13ContactUs: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "13. Contact Us")
      LegalBodyText(text:
        "If you have questions about this Privacy Policy or our privacy practices, please contact us at:"
      )

      VStack(alignment: .leading, spacing: 8) {
        Text("The Recruiting Compass")
          .font(.headline)
          .foregroundStyle(Color.darkSlate)

        Text("Olmsted Township, OH 44138")
          .font(.body)
          .foregroundStyle(Color.secondaryText)

        HStack(spacing: 4) {
          Text("Privacy inquiries:")
            .font(.body)
            .foregroundStyle(Color.secondaryText)
          LegalEmailLink(email: "privacy@therecruitingcompass.com")
        }

        HStack(spacing: 4) {
          Text("General support:")
            .font(.body)
            .foregroundStyle(Color.secondaryText)
          LegalEmailLink(email: "support@therecruitingcompass.com")
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
