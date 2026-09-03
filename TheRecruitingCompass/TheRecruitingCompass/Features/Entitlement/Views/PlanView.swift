import SwiftUI

struct PlanView: View {
  @Environment(EntitlementStore.self) private var entitlementStore
  @Environment(FamilyManager.self) private var familyManager

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("Current plan")
            .font(.caption)
            .foregroundStyle(.secondary)
          if entitlementStore.isLoading || !entitlementStore.hasLoaded {
            ProgressView()
          } else {
            Text(entitlementStore.planLabel)
              .font(.headline)
          }
          if let message = entitlementStore.errorMessage {
            Text(message)
              .font(.caption)
              .foregroundStyle(.red)
          } else if entitlementStore.subscription?.status == .founding {
            Text("""
              You joined during our founding period. Your family keeps full access at no \
              charge for as long as this account is active. Thank you for being early.
              """)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
      } footer: {
        Text("Your plan covers your whole family — every parent and athlete in this family account.")
      }
    }
    .navigationTitle("Plan")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await entitlementStore.load(familyUnitId: familyManager.familyUnitId)
    }
  }
}

#Preview {
  NavigationStack {
    PlanView()
      .environment(EntitlementStore())
      .environment(FamilyManager.shared)
  }
}
