import SwiftUI

struct CoachFollowupRow: View {
  let coach: Coach
  let schoolName: String
  let onEmail: () -> Void
  let onText: () -> Void
  let onProfile: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onProfile) {
        VStack(alignment: .leading, spacing: 2) {
          Text(coach.fullName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.primary)
          Text("\(schoolName) · \(CoachFollowup.daysSinceLabel(coach, asOf: Date.now))")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(String(localized: "View \(coach.fullName) profile"))

      if coach.email != nil {
        iconAction(systemImage: "envelope",
                   label: String(localized: "Email \(coach.fullName)"),
                   action: onEmail)
      }
      if coach.phone != nil {
        iconAction(systemImage: "message",
                   label: String(localized: "Text \(coach.fullName)"),
                   action: onText)
      }
    }
    .padding(.vertical, 6)
  }

  /// Compact trailing action: a small icon with a full 44×44 hit target.
  private func iconAction(systemImage: String, label: String,
                          action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.body)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.bordered)
    .accessibilityLabel(label)
  }
}
