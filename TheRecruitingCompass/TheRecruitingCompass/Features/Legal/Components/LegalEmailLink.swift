import SwiftUI
import UIKit

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
        .foregroundStyle(Color.accentBlue)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(localized: "Email \(email.replacing("@", with: " at ").replacing(".", with: " dot "))"))
        .accessibilityHint("Opens Mail app")
        .alert("Email not available on this device", isPresented: $showMailUnavailableAlert) {
        }
      } else {
        Text(email)
          .font(.body)
          .foregroundStyle(Color.accentBlue)
      }
    }
  }
}
