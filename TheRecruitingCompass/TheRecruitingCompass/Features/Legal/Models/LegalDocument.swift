import Foundation
import SwiftUI

/// Identifies which legal document sheet to present (Terms of Service, Privacy Policy).
/// Use with `.sheet(item:)` to present a single Legal sheet from multiple entry points.
enum LegalDocument: Identifiable {
  case termsOfService
  case privacyPolicy

  var id: Self { self }

  @ViewBuilder
  var view: some View {
    switch self {
    case .termsOfService:
      TermsOfServiceView()
    case .privacyPolicy:
      PrivacyPolicyView()
    }
  }
}
