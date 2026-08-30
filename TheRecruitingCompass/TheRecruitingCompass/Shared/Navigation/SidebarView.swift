import SwiftUI

/// iPad sidebar navigation, listing `AppDestination` items grouped by section
/// with the signed-in user's profile pinned at the bottom.
struct SidebarView: View {
  @Binding var selection: AppDestination?
  @Environment(AuthManager.self) private var authManager

  var body: some View {
    List(selection: $selection) {
      Section {
        ForEach(itemsForSection(.main)) { destination in
          sidebarLabel(destination)
        }
      }

      Section("More") {
        ForEach(itemsForSection(.more)) { destination in
          sidebarLabel(destination)
        }
      }

      Section {
        ForEach(itemsForSection(.bottom)) { destination in
          sidebarLabel(destination)
        }
        profileRow
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("myCompass")
  }

  private func itemsForSection(_ section: AppDestination.SidebarSection) -> [AppDestination] {
    AppDestination.allCases.filter { $0.section == section }
  }

  private func sidebarLabel(_ destination: AppDestination) -> some View {
    Label(destination.label, systemImage: destination.systemImage)
      .tag(destination)
  }

  @ViewBuilder
  private var profileRow: some View {
    if let user = authManager.user {
      HStack(spacing: 12) {
        Circle()
          .fill(Color.accentColor.opacity(0.2))
          .frame(width: 32, height: 32)
          .overlay {
            Text(initials(for: user))
              .font(.caption.bold())
              .foregroundStyle(Color.accentColor)
          }
        VStack(alignment: .leading, spacing: 2) {
          Text(user.fullName ?? user.email)
            .font(.subheadline.weight(.medium))
          Text(user.email)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Profile: \(user.fullName ?? user.email)")
    }
  }

  private func initials(for user: User) -> String {
    guard let name = user.fullName, !name.isEmpty else {
      return String(user.email.prefix(2)).uppercased()
    }
    let words = name.split(separator: " ").prefix(2)
    return words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
  }
}
