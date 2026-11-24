import SwiftUI

/// Wires a screen's `WriteGate` to the app's entitlement store and presents the notice with a way to the Plan screen.
private struct WriteGatedModifier: ViewModifier {
  @Environment(EntitlementStore.self) private var entitlementStore
  @Bindable var gate: WriteGate
  @State private var isShowingPlan = false

  func body(content: Content) -> some View {
    content.background { noticeHost }
  }

  /// Hosted on its own invisible view so its alert and sheet never compete with the screen's existing ones.
  @ViewBuilder
  private var noticeHost: some View {
    Color.clear
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear { gate.attach(to: entitlementStore) }
      .alert(WriteGate.noticeTitle, isPresented: $gate.isShowingNotice) {
        Button(WriteGate.viewPlanButton) { isShowingPlan = true }
        Button(WriteGate.closeButton, role: .cancel) {}
      } message: {
        Text(WriteGate.subscriptionMessage)
      }
      .sheet(isPresented: $isShowingPlan) {
        NavigationStack {
          PlanView()
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") { isShowingPlan = false }
              }
            }
        }
      }
  }
}

extension View {
  func writeGated(by gate: WriteGate) -> some View {
    modifier(WriteGatedModifier(gate: gate))
  }
}
