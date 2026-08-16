import SwiftUI

struct TermsOfServiceView: View {
  @State private var viewModel = TermsOfServiceViewModel()
  @Environment(\.dismiss) var dismiss

  private let contactBoxBackground = Color.Surface.muted
  private let sectionSpacing: CGFloat = 16
  private let padding: CGFloat = 20

  var body: some View {
    NavigationStack {
      contentView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Surface.background)
        .navigationTitle("Terms and Conditions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Back") { dismiss() }
              .foregroundStyle(Color.darkSlate)
              .accessibilityLabel(String(localized: "Back"))
              .accessibilityHint("Dismiss Terms and Conditions")
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

        section1AgreementToTerms
        section2UseLicense
        section3Disclaimer
        section4Limitations
        section5AccuracyOfMaterials
        section6Links
        section7Modifications
        section8GoverningLaw
        section9UserAccounts
        section10ProhibitedActivities
        section11AgeRestriction
        section12Arbitration
        section13AccountTermination
        section14UserContent
        section15ThirdPartyData
        section16FitScore
        section17EmailCommunications
        section18Indemnification
        section19Severability
        section20DMCA
        section21GeneralProvisions
        section22ContactInformation
      }
      .padding(padding)
    }
  }

  // MARK: - Section 1: Agreement to Terms

  @ViewBuilder
  private var section1AgreementToTerms: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "1. Agreement to Terms")
      LegalBodyText(text:
        "By accessing or using The Recruiting Compass service (\"Service\"), you agree to be bound by these Terms and Conditions. " +
          "If you do not agree to these terms, please do not use our Service."
      )
      LegalBodyText(text:
        "If you are under 18 years of age, you may use the Service only with the involvement, supervision, and consent of a " +
          "parent or legal guardian who agrees to these Terms on your behalf and accepts responsibility for your use of the Service. " +
          "By creating or approving an account for a minor, the parent or guardian represents that they have the legal authority to " +
          "enter into these Terms on the minor's behalf. See Section 11 for details."
      )
    }
  }

  // MARK: - Section 2: Use License

  @ViewBuilder
  private var section2UseLicense: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "2. Use License")
      LegalBodyText(text: "Permission is granted to temporarily access the materials on The Recruiting Compass for personal, non-commercial use only. " +
        "This is the grant of a license, not a transfer of title, and under this license you may not:")
      LegalBulletList(items: [
        "Modify or copy the materials",
        "Use the materials for any commercial purpose or for any public display",
        "Attempt to decompile or reverse engineer any software contained in the Service",
        "Remove any copyright or other proprietary notations from the materials",
        "Transfer the materials to another person or \"mirror\" the materials on any other server"
      ])
    }
  }

  // MARK: - Section 3: Disclaimer

  @ViewBuilder
  private var section3Disclaimer: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "3. Disclaimer")
      LegalBodyText(text:
        "The materials on The Recruiting Compass are provided on an \"as is\" basis. The Recruiting Compass makes no warranties, expressed or implied, " +
          "and hereby disclaims and negates all other warranties including, without limitation, implied warranties or conditions of merchantability, " +
          "fitness for a particular purpose, or non-infringement of intellectual property or other violation of rights."
      )
    }
  }

  // MARK: - Section 4: Limitations of Liability

  @ViewBuilder
  private var section4Limitations: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "4. Limitations of Liability")
      LegalBodyText(text:
        "To the fullest extent permitted by applicable law, in no event shall The Recruiting Compass or its suppliers be liable for any indirect, " +
          "incidental, special, consequential, or punitive damages (including, without limitation, damages for loss of data or profit, or due to " +
          "business interruption) arising out of the use or inability to use the Service, even if The Recruiting Compass has been notified of the " +
          "possibility of such damage."
      )
      LegalBodyText(text:
        "In all cases, The Recruiting Compass's total liability to you for any claim arising from or relating to these Terms or the Service shall not " +
          "exceed the greater of (a) $100.00 USD or (b) the total amount you paid to The Recruiting Compass in the twelve (12) months preceding the claim."
      )
    }
  }

  // MARK: - Section 5: Accuracy of Materials

  @ViewBuilder
  private var section5AccuracyOfMaterials: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "5. Accuracy of Materials")
      LegalBodyText(text:
        "The materials appearing on The Recruiting Compass could include technical, typographical, or photographic errors. " +
          "The Recruiting Compass does not warrant that any of the materials on its Service are accurate, complete, or current. " +
          "The Recruiting Compass may make changes to the materials at any time without notice."
      )
    }
  }

  // MARK: - Section 6: Links

  @ViewBuilder
  private var section6Links: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "6. Links")
      LegalBodyText(text:
        "The Recruiting Compass has not reviewed all of the sites linked to its Service and is not responsible for the contents of any such linked site. " +
          "The inclusion of any link does not imply endorsement by The Recruiting Compass. Use of any such linked website is at the user's own risk."
      )
    }
  }

  // MARK: - Section 7: Modifications to Terms

  @ViewBuilder
  private var section7Modifications: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "7. Modifications to Terms")
      LegalBodyText(text:
        "The Recruiting Compass may revise these Terms at any time. For material changes — including changes to pricing, data practices, arbitration " +
          "terms, or core Service features — we will provide at least 14 days' advance notice via an in-app notification and, where feasible, email. " +
          "Your continued use of the Service after the effective date of any change constitutes your acceptance of the updated Terms."
      )
      LegalBodyText(text:
        "For minor, non-material changes (such as clarifications or formatting updates), the updated Terms are effective immediately upon posting."
      )
    }
  }

  // MARK: - Section 8: Governing Law

  @ViewBuilder
  private var section8GoverningLaw: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "8. Governing Law")
      LegalBodyText(text:
        "These Terms and Conditions are governed by and construed in accordance with the laws of the State of Ohio, United States, without regard to " +
          "conflict of law principles. You irrevocably submit to the exclusive jurisdiction of the state and federal courts located in Cuyahoga County, " +
          "Ohio for any matter not subject to arbitration under Section 12."
      )
    }
  }

  // MARK: - Section 9: User Accounts

  @ViewBuilder
  private var section9UserAccounts: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "9. User Accounts")
      LegalBodyText(text: "When you create an account with us, you must provide accurate and complete information. You agree to:")
      LegalBulletList(items: [
        "Provide accurate, current, and complete information during registration",
        "Maintain and promptly update your account information and keep your password secure",
        "Accept responsibility for all activities that occur under your account",
        "Notify us immediately of any unauthorized use of your account or any other breach of security"
      ])
    }
  }

  // MARK: - Section 10: Prohibited Activities

  @ViewBuilder
  private var section10ProhibitedActivities: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "10. Prohibited Activities")
      LegalBodyText(text: "You agree not to engage in any of the following prohibited activities:")
      LegalBulletList(items: [
        "Violating any applicable laws or regulations",
        "Infringing upon intellectual property rights of The Recruiting Compass or others",
        "Harassing, threatening, or defaming any person or entity",
        "Attempting to gain unauthorized access to the Service or its systems",
        "Transmitting viruses or malicious code",
        "Scraping, crawling, or using automated means to extract data from the Service",
        "Impersonating any person or entity",
        "Sending unsolicited messages or spam to other users of the Service",
        "Using the Service in a manner that violates NCAA amateurism rules, applicable recruiting regulations, or any other governing body's rules regarding athletic recruiting"
      ])
    }
  }

  // MARK: - Section 11: Age Restriction & Minors

  @ViewBuilder
  private var section11AgeRestriction: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "11. Age Restriction & Minors")
      LegalBodyText(text:
        "The Service is not directed to children under the age of 13. We do not knowingly collect personal information from anyone under 13. " +
          "If we discover that a child under 13 has provided personal information, we will delete it immediately."
      )
      LegalBodyText(text:
        "Athletes aged 13 to 17 may use the Service only with the consent and supervision of a parent or legal guardian. A parent or guardian must " +
          "agree to these Terms on the minor's behalf — either by creating the family unit and inviting the minor, or by consenting to the minor's " +
          "account at registration. The parent or guardian is the responsible party for the minor's account and use of the Service, and any agreement " +
          "to arbitration or other provisions in these Terms is entered into by that parent or guardian on the minor's behalf."
      )
      LegalBodyText(text:
        "If you are a parent or guardian and believe your child under 13 has registered for the Service, or you wish to review, correct, or delete " +
          "information relating to your minor, please contact us at support@therecruitingcompass.com."
      )
    }
  }

  // MARK: - Section 12: Dispute Resolution & Arbitration

  @ViewBuilder
  private var section12Arbitration: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "12. Dispute Resolution & Arbitration")
      LegalBodyText(text:
        "Informal resolution first. Before starting an arbitration, you and The Recruiting Compass agree to try to resolve any dispute informally. " +
          "You agree to send a written description of the dispute to support@therecruitingcompass.com, and both parties will negotiate in good faith " +
          "for at least 60 days before either may commence arbitration."
      )
      LegalBodyText(text:
        "Any dispute, claim, or controversy arising out of or relating to these Terms or the Service that is not resolved informally shall be resolved " +
          "by binding arbitration administered by the American Arbitration Association (AAA) under its Consumer Arbitration Rules, rather than in court."
      )
      LegalBodyText(text:
        "Class Action Waiver: You waive your right to participate in any class action lawsuit or class-wide arbitration. All claims must be brought in " +
          "your individual capacity, not as a plaintiff or class member in any purported class or representative proceeding."
      )
      LegalBodyText(text:
        "Severability of this waiver. If the class-action waiver above is found unenforceable as to a particular claim, then that claim (and only that " +
          "claim) will be severed from arbitration and brought in a court of competent jurisdiction; the remainder of this arbitration agreement will continue to apply."
      )
      LegalBodyText(text:
        "Delegation. The arbitrator has the exclusive authority to resolve any dispute about the interpretation, applicability, enforceability, or " +
          "formation of this arbitration agreement, including whether a claim is subject to arbitration — except that a court decides the enforceability " +
          "of the class-action waiver above."
      )
      LegalBodyText(text:
        "Arbitration fees. For claims subject to the AAA Consumer Arbitration Rules, The Recruiting Compass will pay the AAA filing, administrative, and " +
          "arbitrator fees to the extent those Rules require, and otherwise as required by applicable law."
      )
      LegalBodyText(text:
        "Mass filings. If 25 or more similar claims are asserted against The Recruiting Compass by or with the assistance of the same or coordinated " +
          "counsel, the claims will be administered in staged batches of no more than 50 (with representative \"bellwether\" proceedings first), and any " +
          "applicable statutes of limitations will be tolled for claims awaiting their batch."
      )
      LegalBodyText(text:
        "Jury-trial waiver & venue. You and The Recruiting Compass each waive the right to a trial by jury. Any in-person arbitration hearing, and any " +
          "action permitted to proceed in court, will take place in Cuyahoga County, Ohio, unless applicable law or the AAA Rules require otherwise."
      )
      LegalBodyText(text:
        "This arbitration provision does not apply to claims that qualify for small claims court. This arbitration provision is governed by the Federal Arbitration Act."
      )
      LegalBodyText(text:
        "Your right to opt out: You may opt out of this arbitration agreement and class-action waiver by sending written notice to " +
          "support@therecruitingcompass.com within 30 days of first accepting these Terms. Your notice must include your name and the email address " +
          "associated with your account. Opting out will not affect any other part of these Terms."
      )
    }
  }

  // MARK: - Section 13: Account Termination

  @ViewBuilder
  private var section13AccountTermination: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "13. Account Termination")
      LegalBodyText(text:
        "The Recruiting Compass reserves the right to suspend or terminate your account and access to the Service at any time, with or without notice, " +
          "for conduct that we believe violates these Terms or is harmful to other users, The Recruiting Compass, or third parties, or for any other " +
          "reason at our sole discretion."
      )
      LegalBodyText(text:
        "Upon termination, your right to use the Service will immediately cease. Your data will be handled in accordance with our Privacy Policy " +
          "retention schedule. You may also delete your own account at any time through your account settings."
      )
    }
  }

  // MARK: - Section 14: User Content & Data Ownership

  @ViewBuilder
  private var section14UserContent: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "14. User Content & Data Ownership")
      LegalBodyText(text:
        "You retain ownership of all data and content you enter into the Service, including schools, coaches, interaction notes, and academic " +
          "information (\"User Content\"). By using the Service, you grant The Recruiting Compass a limited, non-exclusive license to store, display, and " +
          "process your User Content solely to provide and improve the Service."
      )
      LegalBodyText(text:
        "School, program, and institutional data sourced from the U.S. Department of Education College Scorecard API or other third-party sources is " +
          "provided by The Recruiting Compass as a reference resource. You may not export, redistribute, or commercially exploit this third-party data."
      )
      LegalBodyText(text:
        "The Recruiting Compass may use aggregated, anonymized, non-personally identifiable data derived from Service usage for product improvement, " +
          "analytics, and research."
      )
    }
  }

  // MARK: - Section 15: Third-Party Data Disclaimer

  @ViewBuilder
  private var section15ThirdPartyData: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "15. Third-Party Data Disclaimer")
      LegalBodyText(text:
        "School and program information displayed in the Service may be sourced from the U.S. Department of Education College Scorecard API and other " +
          "publicly available sources. This data is provided for reference purposes only and may not reflect current institutional policies, admissions " +
          "requirements, program offerings, or other statistics. The Recruiting Compass makes no representations about the accuracy, completeness, or " +
          "timeliness of third-party data and is not responsible for any decisions made based on it."
      )
    }
  }

  // MARK: - Section 16: Fit Score Disclaimer

  @ViewBuilder
  private var section16FitScore: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "16. Fit Score Disclaimer")
      LegalBodyText(text:
        "The Recruiting Compass calculates a \"Fit Score\" as an algorithmic estimate to help athletes gauge potential compatibility with schools. " +
          "Fit Scores are based on user-entered data and publicly available school information."
      )
      LegalBodyText(text:
        "Fit Scores are not an official assessment, guarantee of admission, scholarship offer, or endorsement by any institution or athletic program. " +
          "They are a general gauge only and should be used as one of many tools in the recruiting process — not as the sole basis for any decision."
      )
      LegalBodyText(text:
        "Note: The relationship between Fit Scores and NCAA recruiting rules is subject to attorney review."
      )
    }
  }

  // MARK: - Section 17: Email Communications

  @ViewBuilder
  private var section17EmailCommunications: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "17. Email Communications")
      LegalBodyText(text:
        "By creating an account, you agree to receive transactional emails necessary to operate the Service, including account confirmations, password " +
          "resets, and family invitation notifications. These transactional emails cannot be opted out of while your account is active."
      )
      LegalBodyText(text:
        "You may also receive non-transactional emails such as product updates, recruiting tips and educational content, and (when applicable) " +
          "promotional information about paid features. You may opt out of non-transactional emails at any time by clicking the unsubscribe link in any " +
          "such email or by updating your preferences in your account settings."
      )
    }
  }

  // MARK: - Section 18: Indemnification

  @ViewBuilder
  private var section18Indemnification: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "18. Indemnification")
      LegalBodyText(text:
        "You agree to indemnify, defend, and hold harmless The Recruiting Compass and its officers, directors, employees, contractors, and agents from " +
          "and against any and all claims, liabilities, damages, losses, and expenses (including reasonable attorneys' fees) arising out of or in any " +
          "way connected with: (a) your access to or use of the Service; (b) your violation of these Terms; or (c) your infringement of any intellectual " +
          "property or other rights of any third party."
      )
    }
  }

  // MARK: - Section 19: Severability & Entire Agreement

  @ViewBuilder
  private var section19Severability: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "19. Severability & Entire Agreement")
      LegalBodyText(text:
        "If any provision of these Terms is held to be invalid, illegal, or unenforceable, the remaining provisions shall continue in full force and " +
          "effect. These Terms, together with the Privacy Policy, constitute the entire agreement between you and The Recruiting Compass with respect to " +
          "the Service and supersede all prior agreements and understandings."
      )
    }
  }

  // MARK: - Section 20: Copyright & DMCA Policy

  @ViewBuilder
  private var section20DMCA: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "20. Copyright & DMCA Policy")
      LegalBodyText(text:
        "We respect the intellectual property rights of others and expect users to do the same. If you believe that content on the Service infringes " +
          "your copyright, you may submit a notice under the Digital Millennium Copyright Act (DMCA) to our designated agent at " +
          "support@therecruitingcompass.com. Your notice must include: (a) identification of the copyrighted work claimed to be infringed; " +
          "(b) identification of the material claimed to be infringing and its location on the Service; (c) your contact information; (d) a statement " +
          "that you have a good-faith belief the use is not authorized; and (e) a statement, under penalty of perjury, that the information is accurate " +
          "and that you are the copyright owner or authorized to act on their behalf."
      )
      LegalBodyText(text:
        "We will respond to valid notices in accordance with the DMCA, including by removing or disabling access to the allegedly infringing material " +
          "and, where appropriate, terminating the accounts of repeat infringers."
      )
    }
  }

  // MARK: - Section 21: General Provisions

  @ViewBuilder
  private var section21GeneralProvisions: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "21. General Provisions")
      LegalBulletList(items: [
        "Assignment: You may not assign or transfer these Terms without our prior written consent. We may assign these Terms in connection with a merger, acquisition, reorganization, or sale of assets.",
        "Force Majeure: We are not liable for any failure or delay in performance caused by events beyond our reasonable control, including acts of God, outages, or third-party service failures.",
        "No Waiver: Our failure to enforce any provision of these Terms is not a waiver of that provision or of our right to enforce it later.",
        "Survival: Provisions that by their nature should survive termination — including the disclaimers, limitations of liability, arbitration agreement, indemnification, and ownership terms — survive termination of your account or these Terms.",
        "Electronic Communications (E-SIGN): You consent to receive communications from us electronically, and you agree that electronic notices, agreements, and disclosures satisfy any legal requirement that such communications be in writing."
      ])
    }
  }

  // MARK: - Section 22: Contact Information

  @ViewBuilder
  private var section22ContactInformation: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "22. Contact Information")
      LegalBodyText(text:
        "If you have any questions about these Terms and Conditions, please contact us:"
      )

      VStack(alignment: .leading, spacing: 8) {
        Text("The Recruiting Compass")
          .font(.headline)
          .foregroundStyle(Color.darkSlate)

        Text("Olmsted Township, OH 44138")
          .font(.body)
          .foregroundStyle(Color.secondaryText)

        HStack(spacing: 4) {
          Text("Email:")
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
  TermsOfServiceView()
}
