import SwiftUI

struct CoachFollowupRow: View {
  let coach: Coach
  let schoolName: String
  let onEmail: () -> Void
  let onText: () -> Void
  let onProfile: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button(action: onProfile) {
        VStack(alignment: .leading, spacing: 2) {
          Text(coach.fullName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.primary)
          Text(schoolName)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
          Text(CoachFollowup.daysSinceLabel(coach, asOf: Date.now))
            .font(.caption2)
            .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "View \(coach.fullName) profile"))

      HStack(spacing: 12) {
        if coach.email != nil {
          Button(action: onEmail) {
            Label(String(localized: "Email"), systemImage: "envelope")
              .font(.caption)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Email \(coach.fullName)"))
        }
        if coach.phone != nil {
          Button(action: onText) {
            Label(String(localized: "Text"), systemImage: "message")
              .font(.caption)
          }
          .buttonStyle(.bordered)
          .accessibilityLabel(String(localized: "Text \(coach.fullName)"))
        }
        Spacer()
      }
    }
    .padding(.vertical, 4)
  }
}
