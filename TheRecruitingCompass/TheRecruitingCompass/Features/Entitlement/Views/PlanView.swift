import SwiftUI

struct PlanView: View {
  static let foundingCopy = """
    You joined during our founding period. Your family keeps full access at no \
    charge for as long as this account is active. Thank you for being early.
    """
  static let footerCopy = "Your plan covers one player's family. Each sibling gets their own family."

  @Environment(EntitlementStore.self) private var entitlementStore
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager
  @Environment(FeatureFlagStore.self) private var flags: FeatureFlagStore?
  @Environment(BillingSession.self) private var billing: BillingSession?
  @State private var holdsSubscription = false
  @State private var isShowingPaywall = false

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
            Text(Self.foundingCopy)
              .font(.brand(.subheadline))
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
      } footer: {
        Text(Self.footerCopy)
      }

      if PaywallAccess.showsAskAParentNote(subscription: entitlementStore.subscription, role: authManager.user?.role) {
        Section {
          Text(PaywallAccess.askAParentCopy)
            .font(.brand(.subheadline))
            .foregroundStyle(.secondary)
        }
      }

      if let billing, !planActions.isEmpty {
        Section {
          ForEach(planActions, id: \.self) { action in
            Button(Self.title(for: action)) { perform(action, billing: billing) }
              .frame(minHeight: 44, alignment: .leading)
          }
        }
      }
    }
    .navigationTitle("Plan")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadPlan()
    }
    .task(id: entitlementStore.subscription) {
      holdsSubscription = await billing?.currentProductId(as: authManager.user?.id) != nil
    }
    .sheet(isPresented: $isShowingPaywall) {
      if let billing { PaywallView(session: billing) }
    }
  }

  private var planActions: [PlanAction] {
    PaywallAccess.actions(
      subscription: entitlementStore.subscription, flags: flags, role: authManager.user?.role,
      isConfigured: billing?.purchases.isConfigured ?? false, holdsSubscription: holdsSubscription
    )
  }

  static func title(for action: PlanAction) -> String {
    switch action {
    case .seePlans: String(localized: "See plans")
    case .changePlan: String(localized: "Change plan")
    case .manageSubscription: String(localized: "Manage subscription")
    }
  }

  private func perform(_ action: PlanAction, billing: BillingSession) {
    switch action {
    case .seePlans, .changePlan:
      isShowingPaywall = true
    case .manageSubscription:
      Task { try? await billing.purchases.presentManageSubscriptions() }
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
      .environment(AuthManager.shared)
  }
}
