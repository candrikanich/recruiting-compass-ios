import SwiftUI

struct PlanView: View {
  static let footerCopy = "Your plan covers one player's family. Each sibling's family is $49/year or $6.49/month."

  @Environment(EntitlementStore.self) private var entitlementStore
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("Current plan")
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
          if entitlementStore.isLoading || !entitlementStore.hasLoaded {
            ProgressView()
          } else {
            Text(entitlementStore.planLabel)
              .font(.brand(.headline))
          }
          if let message = entitlementStore.errorMessage {
            Text(message)
              .font(.brand(.caption))
              .foregroundStyle(.red)
            Button("Try again") {
              Task { await loadPlan() }
            }
            .font(.brand(.subheadline))
          } else if entitlementStore.subscription?.status == .founding {
            Text("""
              You joined during our founding period. Your family keeps full access at no \
              charge for as long as this account is active. Thank you for being early.
              """)
              .font(.brand(.subheadline))
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
      } footer: {
        Text(Self.footerCopy)
      }
    }
    .navigationTitle("Plan")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadPlan()
    }
  }

  /// Plan can be opened before family data has loaded (Settings' load is cancelled by the push),
  /// so make sure the family is known before reading its plan.
  private func loadPlan() async {
    if familyManager.familyUnitId == nil {
      await familyManager.loadFamilyData()
    }
    await entitlementStore.load(familyUnitId: familyManager.familyUnitId)
  }
}

#Preview {
  NavigationStack {
    PlanView()
      .environment(EntitlementStore())
      .environment(FamilyManager.shared)
  }
}
