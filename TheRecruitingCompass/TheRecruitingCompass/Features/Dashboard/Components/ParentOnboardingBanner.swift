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
          try? await Task.sleep(nanoseconds: 3_000_000_000)
          showConnected = false
        }
      }
    }
  }

  private var inviteCtaBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "person.badge.plus")
        .font(.title3)
        .foregroundColor(Color(hex: "B45309"))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("Connect your athlete to get started")
          .font(.subheadline.weight(.semibold))
          .foregroundColor(Color(hex: "78350F"))

        Text("Invite them to join your family or share your family code.")
          .font(.caption)
          .foregroundColor(Color(hex: "92400E"))
      }

      Spacer()

      if let onInviteTapped = onInviteTapped {
        VStack(alignment: .trailing, spacing: 6) {
          Button {
            onInviteTapped()
          } label: {
            Text("Invite Athlete")
              .font(.caption.weight(.semibold))
              .foregroundColor(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(Color(hex: "D97706"))
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .accessibilityLabel("Invite athlete with player details")

          NavigationLink(value: DashboardDestination.familyManagement) {
            Text("Family Management")
              .font(.caption2)
              .foregroundColor(Color(hex: "92400E"))
          }
          .accessibilityLabel("Open Family Management")
        }
      } else {
        NavigationLink(value: DashboardDestination.familyManagement) {
          Text("Invite Athlete")
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "D97706"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Go to settings to invite athlete")
      }
    }
    .padding()
    .background(Color(hex: "FFFBEB"))
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color(hex: "F59E0B"))
        .frame(width: 4)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Connect your athlete to get started. Invite them from Family Management.")
  }

  private var connectedBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.title3)
        .foregroundColor(Color(hex: "15803D"))
        .accessibilityHidden(true)

      Text("You're connected! Your athlete has joined your family.")
        .font(.subheadline.weight(.medium))
        .foregroundColor(Color(hex: "14532D"))
    }
    .padding()
    .background(Color(hex: "F0FDF4"))
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color(hex: "22C55E"))
        .frame(width: 4)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("You're connected. Your athlete has joined your family.")
  }
}
