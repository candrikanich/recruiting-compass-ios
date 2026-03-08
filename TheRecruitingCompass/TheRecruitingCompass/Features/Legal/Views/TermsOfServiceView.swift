import SwiftUI

struct TermsOfServiceView: View {
  @State private var viewModel = TermsOfServiceViewModel()
  @Environment(\.dismiss) var dismiss

  private let contactBoxBackground = Color(hex: "F3F4F6")
  private let sectionSpacing: CGFloat = 16
  private let padding: CGFloat = 20

  var body: some View {
    NavigationStack {
      contentView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("Terms and Conditions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Back") { dismiss() }
              .foregroundStyle(Color.darkSlate)
              .accessibilityLabel("Back")
              .accessibilityHint("Dismiss Terms and Conditions")
          }
        }
    }
  }

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
        section11ContactInformation
      }
      .padding(padding)
    }
  }

  // MARK: - Section 1: Agreement to Terms

  private var section1AgreementToTerms: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "1. Agreement to Terms")
      LegalBodyText(text:
        "By accessing or using The Recruiting Compass service (\"Service\"), you agree to be bound by these Terms and Conditions. " +
          "If you do not agree to these terms, please do not use our Service."
      )
    }
  }

  // MARK: - Section 2: Use License

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
        "Transfer the materials to another person or \"mirror\" the materials on any other server",
      ])
    }
  }

  // MARK: - Section 3: Disclaimer

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

  // MARK: - Section 4: Limitations

  private var section4Limitations: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "4. Limitations")
      LegalBodyText(text:
        "In no event shall The Recruiting Compass or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, " +
          "or due to business interruption) arising out of the use or inability to use the materials on The Recruiting Compass, even if The Recruiting Compass " +
          "or an authorized representative has been notified orally or in writing of the possibility of such damage."
      )
    }
  }

  // MARK: - Section 5: Accuracy of Materials

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

  private var section6Links: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "6. Links")
      LegalBodyText(text:
        "The Recruiting Compass has not reviewed all of the sites linked to its Service and is not responsible for the contents of any such linked site. " +
          "The inclusion of any link does not imply endorsement by The Recruiting Compass. Use of any such linked website is at the user's own risk."
      )
    }
  }

  // MARK: - Section 7: Modifications

  private var section7Modifications: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "7. Modifications")
      LegalBodyText(text:
        "The Recruiting Compass may revise these Terms and Conditions at any time without notice. By using this Service you are agreeing to be bound by " +
          "the then current version of these Terms and Conditions. We will notify you of material changes by updating the \"Last Updated\" date."
      )
    }
  }

  // MARK: - Section 8: Governing Law

  private var section8GoverningLaw: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "8. Governing Law")
      LegalBodyText(text:
        "These terms and conditions are governed by and construed in accordance with the laws of the United States and you irrevocably submit to " +
          "the exclusive jurisdiction of the courts in that location."
      )
    }
  }

  // MARK: - Section 9: User Accounts

  private var section9UserAccounts: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "9. User Accounts")
      LegalBodyText(text:"When you create an account with us, you must provide accurate and complete information. You agree to:")
      LegalBulletList(items: [
        "Provide accurate, current, and complete information during registration",
        "Maintain and promptly update your account information and keep your password secure",
        "Accept responsibility for all activities that occur under your account",
        "Notify us immediately of any unauthorized use of your account or any other breach of security",
      ])
    }
  }

  // MARK: - Section 10: Prohibited Activities

  private var section10ProhibitedActivities: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "10. Prohibited Activities")
      LegalBodyText(text:"You agree not to use the Service to:")
      LegalBulletList(items: [
        "Violate any applicable laws or regulations",
        "Infringe upon the intellectual property rights of others",
        "Harass, abuse, or harm another person",
        "Gain unauthorized access to any systems, networks, or accounts",
        "Transmit any viruses, malware, or other harmful code",
      ])
    }
  }

  // MARK: - Section 11: Contact Information

  private var section11ContactInformation: some View {
    VStack(alignment: .leading, spacing: sectionSpacing) {
      LegalSectionHeader(text: "11. Contact Information")
      LegalBodyText(text:
        "If you have questions about these Terms and Conditions, please contact us at:"
      )

      VStack(alignment: .leading, spacing: 8) {
        Text("The Recruiting Compass")
          .font(.headline)
          .foregroundStyle(Color.darkSlate)

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
  TermsOfServiceView()
}
