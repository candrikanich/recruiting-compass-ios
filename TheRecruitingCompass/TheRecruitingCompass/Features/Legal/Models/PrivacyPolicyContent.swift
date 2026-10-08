import Foundation

/// The Privacy Policy text, ported from the web `pages/legal/privacy.vue`. When the web policy changes, port it here,
/// bump `LegalRevision.lastUpdated`, and update `PrivacyPolicyContentTests` so the drift guard stays meaningful.
enum PrivacyPolicyContent {
  enum Block: Equatable {
    case body(String)
    case subheading(String)
    case bullets([String])

    var texts: [String] {
      switch self {
      case .body(let text), .subheading(let text): [text]
      case .bullets(let items): items
      }
    }
  }

  struct Section: Identifiable {
    let heading: String
    let blocks: [Block]
    var id: String { heading }
  }

  struct Contact {
    let name: String
    let address: String
    let privacyEmail: String
    let supportEmail: String
  }

  static let contact = Contact(
    name: "The Recruiting Compass LLC",
    address: "34125 Center Ridge Rd #1012\nNorth Ridgeville, OH 44039",
    privacyEmail: "privacy@therecruitingcompass.com",
    supportEmail: "support@therecruitingcompass.com"
  )

  static let sections: [Section] = [
    introduction, informationWeCollect, howWeUse, thirdPartyDataSources, sharing, dataSecurity,
    retention, privacyRights, cookies, childrenPrivacy, thirdPartyLinks, changes, contactUs
  ]

  private static let introduction = Section(heading: "1. Introduction", blocks: [
    .body(
      "The Recruiting Compass (\"we,\" \"us,\" \"our,\" or \"Company\") is committed to protecting your privacy. " +
        "This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you " +
        "visit our website and use our services."
    ),
    .body(
      "Please read this Privacy Policy carefully. If you do not agree with our policies and practices, " +
        "please do not use our Service. This Policy is incorporated by reference into our Terms and Conditions."
    )
  ])

  private static let informationWeCollect = Section(heading: "2. Information We Collect", blocks: [
    .body("We may collect information about you in a variety of ways:"),
    .subheading("Information You Provide"),
    .bullets([
      "Registration Information: Name, email address, password (stored as a hashed value — never in plaintext), " +
        "date of birth (used to verify age eligibility), and role (parent or player)",
      "Profile Information: Profile photo, graduation year, sport, position, GPA, standardized test scores, " +
        "athletic stats, and recruiting preferences",
      "Recruiting Activity: Schools and college programs you track, coach contact information you enter, " +
        "and interaction notes and communication logs you create",
      "Family Unit Data: Email addresses of family members you invite to join your family unit, which are " +
        "retained until the invitation is accepted, declined, or expires",
      "Preference Data: Location preferences, school type preferences, and other customization settings"
    ]),
    .subheading("Sensitive Information"),
    .body(
      "Some of the profile information we collect — such as a minor's date of birth, academic records " +
        "(GPA, standardized test scores), and graduation year — may be considered sensitive under certain " +
        "state privacy laws. We use this information solely to operate the Service (for example, to enforce " +
        "age eligibility and calculate Fit Scores) and we never sell it or use it for targeted advertising. " +
        "We are not a school or educational agency, and the academic information you enter is not a FERPA " +
        "\"education record\"; it is data you voluntarily provide and control."
    ),
    .subheading("Data We Do Not Collect"),
    .bullets([
      "Health, medical, or injury information",
      "Financial data or payment card information (no payment processor is currently in use)",
      "Social Security numbers or government-issued identification numbers"
    ]),
    .subheading("Automatically Collected Information"),
    .bullets([
      "Log Data: IP address, browser type, pages visited, and time and date stamps",
      "Device Information: Device type, operating system, and unique device identifiers",
      "Usage Analytics: How you interact with our Service, features you use, and actions you take",
      "Cookies: Small data files stored on your device to maintain your session and enhance your experience"
    ])
  ])

  private static let howWeUse = Section(heading: "3. How We Use Your Information", blocks: [
    .body("We use the information we collect for the following purposes:"),
    .bullets([
      "To create and maintain your account",
      "To provide, maintain, and improve the Service",
      "To calculate your Fit Score — an algorithmic estimate of school compatibility based on your profile " +
        "data and publicly available school information",
      "To send transactional emails (account confirmations, family invitations, and password resets)",
      "To send marketing emails — recruiting tips, product updates, and offers — to adults who have opted in " +
        "(see \"Marketing Emails\" below)",
      "To respond to your inquiries and support requests",
      "To analyze usage patterns and improve our offerings",
      "To comply with legal obligations",
      "To prevent fraud and enhance security"
    ]),
    .subheading("Marketing Emails"),
    .body(
      "Marketing emails — recruiting tips, product updates, and offers from us — are optional. Only adult " +
        "account holders can opt in: parents, and players who are 18 or older. The opt-in checkbox at signup " +
        "is unchecked by default, and you can turn marketing emails on or off at any time with the Marketing " +
        "emails switch under Settings → Notifications. Users under 18 are not offered marketing email and do " +
        "not receive it."
    ),
    .body(
      "Every marketing email includes an unsubscribe link. We do not use open or click tracking in our " +
        "emails. Opting out of marketing emails does not affect emails about your account or your use of the " +
        "Service, such as email verification, security notices, deadline alerts, and the weekly digest. " +
        "Deadline alerts and the weekly digest have their own switches under Settings → Notifications."
    ),
    .body(
      "When you opt in or out, we record your choice, when you made it, and where you made it (for example, " +
        "at signup, in Settings, or through an unsubscribe link)."
    ),
    .body(
      "Our marketing site (therecruitingcompass.com) also has a form for getting our monthly " +
        "recruiting-dates email. If you enter your email address there, we add it to our email list and send " +
        "you that email until you unsubscribe. No account is needed. The form is for parents and guardians " +
        "of high school athletes."
    ),
    .body(
      "We use Resend, an email service provider, to send email and to maintain our marketing email list. " +
        "We share your email address and subscription status with Resend for that purpose only. We do not " +
        "sell your personal information or share it for third-party advertising."
    )
  ])

  private static let thirdPartyDataSources = Section(heading: "4. Third-Party Data Sources", blocks: [
    .body(
      "School and program information displayed in the Service may be sourced from the U.S. Department of " +
        "Education College Scorecard API and other publicly available sources. We use this data to provide " +
        "reference information about colleges and athletic programs."
    ),
    .body(
      "We do not sell or share your personal information with third parties for their own advertising or " +
        "marketing purposes."
    )
  ])

  private static let sharing = Section(heading: "5. Sharing Your Information", blocks: [
    .body(
      "We do not sell, trade, or rent your personal information to third parties. We may share information " +
        "in the following circumstances:"
    ),
    .bullets([
      "Service Providers: Third-party vendors who assist in operating our Service (e.g., hosting, email " +
        "delivery), subject to confidentiality obligations. We use Resend to deliver email and to maintain " +
        "our marketing email list.",
      "Family Unit Members: If you are part of a family unit, limited profile information is visible to " +
        "other members of that unit",
      "Legal Requirements: When required by law, court order, or government request",
      "Business Transfers: In connection with a merger, acquisition, or sale of assets, with appropriate " +
        "notice to users",
      "With Your Consent: When you explicitly authorize us to share your information"
    ])
  ])

  private static let dataSecurity = Section(heading: "6. Data Security", blocks: [
    .body(
      "We implement appropriate technical and organizational measures to protect your personal information, " +
        "including:"
    ),
    .bullets([
      "Encryption of data in transit (TLS/HTTPS)",
      "Encryption of data at rest",
      "Row-level security policies enforcing data isolation between accounts",
      "Passwords stored exclusively as hashed values — never in plaintext"
    ]),
    .body(
      "However, no method of transmission over the Internet or electronic storage is completely secure. " +
        "We cannot guarantee absolute security of your information."
    )
  ])

  private static let retention = Section(heading: "7. Data Retention", blocks: [
    .body("We retain your data as follows:"),
    .bullets([
      "Active accounts: Data is retained for as long as your account is active",
      "Pending invitations: Invitation email addresses are retained until the invitation is accepted, " +
        "declined, or expires (invitations expire after 30 days)",
      "Deleted accounts: Following an account deletion request, your personal data is purged within 30 days. " +
        "You may cancel a deletion request within that 30-day window.",
      "Audit logs: Security- and account-related audit logs are retained for up to one year for fraud " +
        "prevention and legal compliance purposes"
    ])
  ])

  private static let privacyRights = Section(heading: "8. Your Privacy Rights", blocks: [
    .body("Depending on your location, you may have the right to:"),
    .bullets([
      "Access the personal information we hold about you",
      "Correct inaccurate or incomplete information",
      "Request deletion of your information",
      "Opt out of certain data processing activities",
      "Request a portable copy of your data",
      "Withdraw consent at any time"
    ]),
    .subheading("California Residents (CCPA)"),
    .body(
      "If you are a California resident, you have the following additional rights under the California " +
        "Consumer Privacy Act:"
    ),
    .bullets([
      "Right to Know: You may request disclosure of the categories and specific pieces of personal " +
        "information we have collected about you",
      "Right to Delete: You may request deletion of your personal information, subject to certain exceptions",
      "Right to Opt Out of Sale: We do not sell your personal information",
      "Right to Non-Discrimination: We will not discriminate against you for exercising your CCPA rights"
    ]),
    .subheading("Residents of Other States"),
    .body(
      "If you reside in a state with a comprehensive consumer privacy law (for example, Virginia, Colorado, " +
        "Connecticut, Texas, Oregon, or Utah), you may have rights similar to those above — including the " +
        "right to access, correct, delete, and obtain a portable copy of your personal data, and to opt out " +
        "of the sale of your personal data, targeted advertising, and certain profiling. We do not sell " +
        "personal data or use it for targeted advertising or profiling in furtherance of decisions that " +
        "produce legal or similarly significant effects."
    ),
    .subheading("Minors"),
    .body(
      "For any user we know to be a minor (under 18), we do not sell their personal data, share it for " +
        "cross-context behavioral advertising, or use it for targeted advertising or profiling. We limit our " +
        "collection and use of a minor's data to what is reasonably necessary to provide the Service."
    ),
    .subheading("Global Privacy Control (GPC)"),
    .body(
      "We honor the Global Privacy Control (GPC) browser signal. If your browser or extension sends a GPC " +
        "signal, we treat it as a valid request to opt out of any sale or sharing of your personal data and " +
        "to disable non-essential analytics for that browser."
    ),
    .body(
      "You can export a portable copy of your data and delete your account directly from your account " +
        "settings (Data & Privacy). To exercise any other right, please contact us at " +
        "privacy@therecruitingcompass.com."
    )
  ])

  private static let cookies = Section(heading: "9. Cookies and Tracking Technologies", blocks: [
    .body(
      "We use cookies and similar tracking technologies to maintain your session and enhance your " +
        "experience. Most web browsers allow you to control cookies through their settings. Disabling " +
        "cookies may affect the functionality of our Service."
    ),
    .body(
      "We use the following third-party providers to operate and improve the Service: Sentry (error " +
        "monitoring), PostHog (product analytics), and Vercel Analytics and Speed Insights (performance " +
        "measurement). These providers process usage and device data on our behalf and are not permitted " +
        "to use it for their own purposes."
    )
  ])

  private static let childrenPrivacy = Section(heading: "10. Children's Privacy (COPPA)", blocks: [
    .body(
      "The Service is not directed to children under the age of 13. We collect date of birth at " +
        "registration to enforce this restriction and do not knowingly create accounts for anyone under 13."
    ),
    .body(
      "Family unit accounts may include athletes between the ages of 13 and 17. Parents and guardians are " +
        "responsible for supervising their minor's use of the Service."
    ),
    .body(
      "We do not send marketing email to users under 18. Only parents, and players who are 18 or older, " +
        "can opt in (see \"Marketing Emails\" in Section 3)."
    ),
    .body(
      "If you are a parent or guardian and believe your child under 13 has registered, or if you wish to " +
        "request deletion of any data collected from a minor in error, please contact us at " +
        "privacy@therecruitingcompass.com."
    )
  ])

  private static let thirdPartyLinks = Section(heading: "11. Third-Party Links", blocks: [
    .body(
      "Our Service may contain links to third-party websites. We are not responsible for the privacy " +
        "practices of those sites. We encourage you to review the privacy policies of any third-party sites " +
        "before providing your information."
    )
  ])

  private static let changes = Section(heading: "12. Changes to This Privacy Policy", blocks: [
    .body(
      "We may update this Privacy Policy from time to time. For material changes — including changes to " +
        "how we collect, use, or share your personal information — we will provide at least 14 days' " +
        "advance notice via an in-app notification and, where feasible, email. Your continued use of the " +
        "Service after the effective date of any change constitutes your acceptance of the updated Policy."
    )
  ])

  private static let contactUs = Section(heading: "13. Contact Us", blocks: [
    .body(
      "If you have questions about this Privacy Policy or our privacy practices, please contact us at:"
    )
  ])
}
