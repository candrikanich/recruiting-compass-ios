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

      if coach.contactEmail != nil {
        iconAction(systemImage: "envelope.fill",
                   label: String(localized: "Email \(coach.fullName)"),
                   action: onEmail)
      }
      if coach.contactPhone != nil {
        iconAction(systemImage: "message.fill",
                   label: String(localized: "Text \(coach.fullName)"),
                   action: onText)
      }
      // No contactable channel — a stale coach you can't act on. Nudge to add contact info
      // (opens the profile) instead of leaving a dead row with no action.
      if coach.contactEmail == nil && coach.contactPhone == nil {
        Button(action: onProfile) {
          Label(String(localized: "Add contact info"), systemImage: "person.crop.circle.badge.plus")
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: "Add contact info for \(coach.fullName)"))
      }
    }
    .padding(.vertical, 6)
  }

  /// Compact trailing action: a 36pt tinted circle bubble centered in a 44pt HIG tap target.
  private func iconAction(systemImage: String, label: String,
                          action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.tint)
        .frame(width: 36, height: 36)
        .background(Color(uiColor: .systemGray6), in: .circle)
        .frame(width: 44, height: 44)
        .contentShape(.circle)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}
