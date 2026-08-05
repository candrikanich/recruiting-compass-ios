import SwiftUI

/// Shown to parents: "Connect your athlete" when no athletes, or one-time "You're connected!" when an athlete has just joined.
struct ParentOnboardingBanner: View {
  /// When set, "Invite Athlete" presents the 2-step wizard instead of navigating to Family Management.
  var onInviteTapped: (() -> Void)?

  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager

  @State private var acknowledged = false
  @State private var showConnected = false

  private var isParent: Bool {
    authManager.user?.role == .parent
  }

  private var hasNoAthletes: Bool {
    familyManager.athletes.isEmpty
  }

  private var ackKey: String {
    guard let id = authManager.user?.id else { return "family_connected_ack_unknown" }
    return "family_connected_ack_\(id)"
  }

  private var showInviteCta: Bool {
    isParent && hasNoAthletes && !acknowledged
  }

  var body: some View {
    Group {
      if showInviteCta {
        inviteCtaBanner
      } else if showConnected {
        connectedBanner
      }
    }
    .onAppear {
      acknowledged = UserDefaults.standard.bool(forKey: ackKey)
    }
    .onChange(of: familyManager.athletes.count) { _, count in
      if isParent && count > 0 && !acknowledged {
        showConnected = true
        UserDefaults.standard.set(true, forKey: ackKey)
        acknowledged = true
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(3))
          showConnected = false
        }
      }
    }
  }

  @ViewBuilder
  private var inviteCtaBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "person.badge.plus")
        .font(.title3)
        .foregroundStyle(Color.amberGold)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("Connect your athlete to get started")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.warningBannerTitle)

        Text("Invite them to join your family or share your family code.")
          .font(.caption)
          .foregroundStyle(Color.warningBannerBody)
      }

      Spacer()

      if let onInviteTapped {
        VStack(alignment: .trailing, spacing: 6) {
          Button {
            onInviteTapped()
          } label: {
            Text("Invite Athlete")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color.Surface.warningCTA)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .accessibilityLabel(String(localized: "Invite athlete with player details"))

          NavigationLink(value: DashboardDestination.familyManagement) {
            Text("Family Management")
              .font(.caption)
              .foregroundStyle(Color.warningBannerBody)
          }
          .accessibilityLabel(String(localized: "Open Family Management"))
        }
      } else {
        NavigationLink(value: DashboardDestination.familyManagement) {
          Text("Invite Athlete")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.Surface.warningCTA)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(String(localized: "Go to settings to invite athlete"))
      }
    }
    .padding()
    .background(Color.Surface.warningTint)
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color.Surface.warningAccent)
        .frame(width: 4)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var connectedBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.title3)
        .foregroundStyle(Color.successBannerIcon)
        .accessibilityHidden(true)

      Text("You're connected! Your athlete has joined your family.")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Color.successBannerText)
    }
    .padding()
    .background(Color.Surface.successTint)
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color.Surface.successAccent)
        .frame(width: 4)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "You're connected. Your athlete has joined your family."))
  }
}
