import SwiftUI

/// Compact identity toolbar: small school-logo avatar, name + role, and
/// edit / delete actions — matching the coach-detail Figma frame.
struct CoachDetailHeader: View {
  let coach: Coach
  let school: School?
  var onEdit: () -> Void = {}
  var onDelete: () -> Void = {}

  var body: some View {
    HStack(spacing: 12) {
      SchoolLogoAvatar(logoUrl: school?.faviconUrl, initials: coach.initials,
                       size: 40, accessibilitySize: 52, cornerRadius: 10)

      VStack(alignment: .leading, spacing: 2) {
        Text(coach.fullName)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Text(coach.role.displayName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 8)

      iconButton(system: "pencil", tint: Color.Brand.blue600, bg: Color.Brand.blue100,
                 label: "Edit coach", action: onEdit)
      iconButton(system: "trash", tint: Color.Brand.red600, bg: Color.Brand.red100,
                 label: "Delete coach", action: onDelete)
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private func iconButton(system: String, tint: Color, bg: Color,
                          label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .accessibilityLabel(label)
  }
}

#Preview {
  CoachDetailHeader(
    coach: Coach(
      id: "1", firstName: "Dana", lastName: "Whitfield", position: "head",
      schoolId: "school-1", createdAt: "2025-01-01T00:00:00Z", updatedAt: "2026-01-15T10:00:00Z"
    ),
    school: nil
  )
  .padding()
}
