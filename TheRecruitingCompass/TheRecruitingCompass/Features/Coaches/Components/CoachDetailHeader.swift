import SwiftUI

/// Identity card: school-logo avatar, name / role / school, edit & delete
/// actions, and a contact block (email, phone, socials) — mirroring the web
/// coach identity card.
struct CoachDetailHeader: View {
  let coach: Coach
  let school: School?
  var onEdit: () -> Void = {}
  var onDelete: () -> Void = {}

  @Environment(\.openURL) private var openURL

  private var hasContact: Bool {
    coach.contactEmail != nil || coach.contactPhone != nil
      || coach.contactTwitter != nil || coach.contactInstagram != nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
          if let school {
            Text(school.name)
              .font(.subheadline)
              .foregroundStyle(Color.accentBlue)
          }
        }

        Spacer(minLength: 8)

        iconButton(system: "pencil", tint: Color.Brand.blue600, bg: Color.Brand.blue100,
                   label: "Edit coach", action: onEdit)
        iconButton(system: "trash", tint: Color.Brand.red600, bg: Color.Brand.red100,
                   label: "Delete coach", action: onDelete)
      }

      if hasContact {
        Divider()
        contactBlock
      }
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var contactBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let email = coach.contactEmail {
        contactRow(icon: "envelope", asset: nil, text: email, tint: Color.accentBlue) {
          open(.email(email), value: email)
        }
      }
      if let phone = coach.contactPhone {
        contactRow(icon: "phone", asset: nil, text: PhoneFormatter.formatDisplay(phone), tint: .primary) {
          open(.call(phone), value: phone)
        }
      }
      if coach.contactTwitter != nil || coach.contactInstagram != nil {
        HStack(spacing: 16) {
          if let twitter = coach.contactTwitter {
            socialLink(asset: "LogoX", handle: twitter) { open(.twitter(twitter), value: twitter) }
          }
          if let instagram = coach.contactInstagram {
            socialLink(asset: "LogoInstagram", handle: instagram) { open(.instagram(instagram), value: instagram) }
          }
        }
      }
    }
  }

  private func open(_ type: CommunicationType, value: String) {
    guard let url = type.url(for: value) else { return }
    openURL(url)
  }

  @ViewBuilder
  private func contactRow(icon: String?, asset: String?, text: String, tint: Color,
                          action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let icon {
          Image(systemName: icon).font(.caption).frame(width: 16).foregroundStyle(.secondary)
        }
        Text(text).font(.subheadline).foregroundStyle(tint)
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(text)
  }

  @ViewBuilder
  private func socialLink(asset: String, handle: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(asset).renderingMode(.template).resizable().scaledToFit()
          .frame(width: 14, height: 14).foregroundStyle(.secondary)
        Text(handle.hasPrefix("@") ? String(handle.dropFirst()) : handle)
          .font(.subheadline).foregroundStyle(.primary)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open \(handle)")
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
      id: "1", firstName: "Chris", lastName: "Andrikanich",
      email: "chris@andrikanich.com", phone: "2164060955", position: "head",
      schoolId: "school-1", twitterHandle: "@alphabet", instagramHandle: "@candrikanich",
      createdAt: "2025-01-01T00:00:00Z", updatedAt: "2026-01-15T10:00:00Z"
    ),
    school: nil
  )
  .padding()
}
