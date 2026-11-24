import SwiftUI

/// Tier picker and purchase screen. Prices and billing lengths come from the store; nothing here knows a price.
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(EntitlementStore.self) private var entitlementStore
  @Environment(FamilyManager.self) private var familyManager
  @Environment(AuthManager.self) private var authManager
  @Environment(FeatureFlagStore.self) private var flags: FeatureFlagStore?
  let session: BillingSession

  @State private var viewModel: PaywallViewModel?
  @State private var presentedLegal: LegalDocument?

  var body: some View {
    NavigationStack {
      Group {
        if let viewModel {
          content(viewModel)
        } else {
          ProgressView()
        }
      }
      .navigationTitle("Choose a plan")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
      .sheet(item: $presentedLegal) { $0.view }
    }
    .task {
      let model = viewModel ?? makeViewModel()
      viewModel = model
      await model.load()
    }
  }

  private func makeViewModel() -> PaywallViewModel {
    PaywallViewModel(
      session: session,
      entitlements: entitlementStore,
      flags: flags,
      userId: { authManager.user?.id },
      familyUnitId: { familyManager.familyUnitId }
    )
  }

  @ViewBuilder
  private func content(_ model: PaywallViewModel) -> some View {
    switch model.phase {
    case .loading:
      ProgressView("Loading plans…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .unavailable:
      ContentUnavailableView {
        Label("Plans aren't available right now", systemImage: "creditcard")
      } description: {
        Text("Check your connection and try again in a moment.")
      } actions: {
        if model.isAvailable {
          Button("Try again") { Task { await model.load() } }
        }
      }
    case .ready:
      picker(model)
        .onChange(of: model.didActivate) { _, activated in
          if activated { dismiss() }
        }
    }
  }

  private func picker(_ model: PaywallViewModel) -> some View {
    @Bindable var model = model
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Pick the plan that fits your family. You can change or cancel it any time in your Apple ID settings.")
          .font(.brand(.subheadline))
          .foregroundStyle(.secondary)

        Picker("Billing period", selection: Binding(get: { model.period }, set: { model.selectPeriod($0) })) {
          Text("Yearly").tag(SubscriptionProduct.Period.annual)
          Text("Monthly").tag(SubscriptionProduct.Period.monthly)
        }
        .pickerStyle(.segmented)

        ForEach(model.tiers) { package in
          TierRow(
            package: package,
            isSelected: model.selectedPackage?.id == package.id,
            isCurrent: model.isCurrent(package)
          ) { model.selectedPackageId = package.id }
        }

        subscribeButton(model)

        if let notice = model.notice {
          Text(notice.message)
            .font(.brand(.footnote))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.updatesFrequently)
        }

        if let package = model.selectedPackage {
          Text(Self.disclosure(for: package))
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 16) {
          Button("Terms of Service") { presentedLegal = .termsOfService }
          Button("Privacy Policy") { presentedLegal = .privacyPolicy }
        }
        .font(.brand(.footnote))

        Button("Restore purchases") { Task { await model.restore() } }
          .font(.brand(.subheadline))
          .disabled(model.busy != nil)
          .frame(minHeight: 44)
      }
      .padding()
    }
  }

  private func subscribeButton(_ model: PaywallViewModel) -> some View {
    Button {
      Task { await model.purchase() }
    } label: {
      Group {
        if model.busy == .purchasing {
          ProgressView()
        } else {
          Text("Subscribe")
        }
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.borderedProminent)
    .disabled(!model.canPurchase)
  }

  /// App Review 3.8(b): the plan's title, how long it bills for, and its price, from the store.
  static func disclosure(for package: PaywallPackage) -> String {
    let title = package.product.tierTitle
    let price = package.priceText
    let period = switch package.product.period {
    case .annual: String(localized: "every year")
    case .monthly: String(localized: "every month")
    }
    return String(
      localized: """
        \(title): \(price) billed \(period). It renews automatically until you cancel. \
        Cancel at least 24 hours before it renews in your Apple ID settings. Payment is charged to your Apple ID.
        """
    )
  }
}

private struct TierRow: View {
  let package: PaywallPackage
  let isSelected: Bool
  let isCurrent: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(package.product.tierTitle)
            .font(.brand(.headline))
          Text(priceLine)
            .font(.brand(.subheadline))
            .foregroundStyle(.secondary)
        }
        Spacer()
        if isCurrent {
          Text("Current plan")
            .font(.brand(.caption))
            .foregroundStyle(.secondary)
        } else {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.accentPrimary : .secondary)
            .accessibilityHidden(true)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .background(Color.Surface.muted, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.accentPrimary : .clear, lineWidth: 2)
      }
    }
    .buttonStyle(.plain)
    .disabled(isCurrent)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var priceLine: String {
    switch package.product.period {
    case .annual: String(localized: "\(package.priceText) per year")
    case .monthly: String(localized: "\(package.priceText) per month")
    }
  }
}
