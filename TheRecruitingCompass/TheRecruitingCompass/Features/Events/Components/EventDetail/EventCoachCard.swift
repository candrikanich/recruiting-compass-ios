import SwiftUI

struct EventCoachCard: View {
  private enum Layout {
    static let cardSpacing: CGFloat = 12
    static let initialsSize: CGFloat = 36
    static let verticalPadding: CGFloat = 4
    static let contactSpacing: CGFloat = 12
    static let nameSpacing: CGFloat = 2
  }

  let coach: Coach

  var body: some View {
    HStack(spacing: Layout.cardSpacing) {
      initialsCircle

      VStack(alignment: .leading, spacing: Layout.nameSpacing) {
        Text(coach.fullName)
          .font(.subheadline)
          .fontWeight(.medium)
        Text(coach.role.displayName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      contactButtons
    }
    .padding(.vertical, Layout.verticalPadding)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(coachAccessibilityLabel)
  }

  private var coachAccessibilityLabel: String {
    var parts = [coach.fullName, coach.role.displayName]
    if let email = coach.email, !email.isEmpty { parts.append(email) }
    if let phone = coach.phone, !phone.isEmpty { parts.append(phone) }
    return String(localized: "\(parts.joined(separator: ", "))")
  }

  @ViewBuilder
  private var initialsCircle: some View {
    Text(coach.initials)
      .font(.caption)
      .bold()
      .foregroundStyle(.white)
      .frame(width: Layout.initialsSize, height: Layout.initialsSize)
      .background(coach.role.badgeColor)
      .clipShape(Circle())
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var contactButtons: some View {
    HStack(spacing: Layout.contactSpacing) {
      if let email = coach.email, !email.isEmpty,
         let emailURL = URL(string: "mailto:\(email)") {
        Link(destination: emailURL) {
          Image(systemName: "envelope")
            .font(.body)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Email \(coach.fullName)"))
      }

      if let phone = coach.phone, !phone.isEmpty,
         let phoneURL = URL(string: "tel:\(phone)") {
        Link(destination: phoneURL) {
          Image(systemName: "phone")
            .font(.body)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Call \(coach.fullName)"))
      }
    }
    .foregroundStyle(Color.accentColor)
  }
}
