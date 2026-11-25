import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "Paywall")

@Observable
@MainActor
final class PaywallViewModel {
  nonisolated deinit {}

  enum Phase: Equatable { case loading, ready, unavailable }
  enum Busy: Equatable { case purchasing, restoring }
  enum Notice: Equatable {
    case purchaseFailed, restoreFailed, nothingToRestore, settingUp

    var message: String {
      switch self {
      case .purchaseFailed: String(localized: "That purchase didn't go through. Try again in a moment.")
      case .restoreFailed: String(localized: "Couldn't restore your purchases. Try again in a moment.")
      case .nothingToRestore: String(localized: "No purchases to restore for this account.")
      case .settingUp:
        String(localized: "Thanks. We're setting up your plan. It will show here in a moment.")
      }
    }
  }

  private(set) var phase = Phase.loading
  private(set) var packages: [PaywallPackage] = []
  private(set) var currentProductId: String?
  private(set) var busy: Busy?
  private(set) var notice: Notice?
  /// Set once the server shows the family on a paid plan; the view closes itself on it.
  private(set) var didActivate = false

  var period = SubscriptionProduct.Period.annual
  var selectedPackageId: String?

  private let session: BillingSession
  private let entitlements: EntitlementStore
  private let flags: FeatureFlagStore?
  private let userId: () -> String?
  private let role: () -> UserRole?
  private let familyUnitId: () -> String?
  private let pollAttempts: Int
  private let pollInterval: Duration
  private let sleep: (Duration) async -> Void

  init(
    session: BillingSession,
    entitlements: EntitlementStore,
    flags: FeatureFlagStore?,
    userId: @escaping () -> String?,
    role: @escaping () -> UserRole?,
    familyUnitId: @escaping () -> String?,
    pollAttempts: Int = 6,
    pollInterval: Duration = .seconds(2),
    sleep: @escaping (Duration) async -> Void = { try? await Task.sleep(for: $0) }
  ) {
    self.session = session
    self.entitlements = entitlements
    self.flags = flags
    self.userId = userId
    self.role = role
    self.familyUnitId = familyUnitId
    self.pollAttempts = pollAttempts
    self.pollInterval = pollInterval
    self.sleep = sleep
  }

  /// Re-read on every action: the family can switch, and the kill switch can flip, while the screen is open.
  var isAvailable: Bool {
    PaywallAccess.isAvailable(
      subscription: entitlements.subscription, flags: flags, role: role(),
      isConfigured: session.purchases.hasAPIKey
    )
  }

  /// Tiers for the chosen billing period, smallest first.
  var tiers: [PaywallPackage] {
    packages
      .filter { $0.product.period == period }
      .sorted { ($0.product.kind.rawValue, $0.product.seats) < ($1.product.kind.rawValue, $1.product.seats) }
  }

  func isCurrent(_ package: PaywallPackage) -> Bool {
    package.product.id == currentProductId
  }

  var selectedPackage: PaywallPackage? {
    tiers.first { $0.id == selectedPackageId && !isCurrent($0) }
  }

  var canPurchase: Bool {
    isAvailable && busy == nil && selectedPackage != nil && session.isIdentified(as: userId())
  }

  func load() async {
    guard isAvailable else {
      phase = .unavailable
      return
    }
    phase = .loading
    notice = nil
    guard await session.ensureIdentified(as: userId()) else {
      phase = .unavailable
      return
    }
    do {
      packages = try await session.purchases.availablePackages()
      currentProductId = try? await session.purchases.currentProductId()
    } catch {
      logger.error("Paywall offering failed to load: \(error.localizedDescription, privacy: .public)")
      packages = []
    }
    selectedPackageId = tiers.first { !isCurrent($0) }?.id
    phase = packages.isEmpty ? .unavailable : .ready
  }

  func selectPeriod(_ newPeriod: SubscriptionProduct.Period) {
    let seats = selectedPackage?.product.seats
    period = newPeriod
    selectedPackageId = tiers.first { $0.product.seats == seats && !isCurrent($0) }?.id
      ?? tiers.first { !isCurrent($0) }?.id
  }

  func purchase() async {
    guard canPurchase, let package = selectedPackage else { return }
    busy = .purchasing
    notice = nil
    defer { busy = nil }
    do {
      switch try await session.purchases.purchase(packageId: package.id) {
      case .cancelled:
        return
      case .purchased:
        await confirmPlan()
      }
    } catch {
      logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
      notice = .purchaseFailed
    }
  }

  func restore() async {
    guard isAvailable, busy == nil, session.isIdentified(as: userId()) else { return }
    busy = .restoring
    notice = nil
    defer { busy = nil }
    do {
      try await session.purchases.restorePurchases()
      guard try await session.purchases.currentProductId() != nil else {
        notice = .nothingToRestore
        return
      }
      await confirmPlan()
    } catch {
      logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
      notice = .restoreFailed
    }
  }

  func manageSubscription() async {
    do {
      try await session.purchases.presentManageSubscriptions()
    } catch {
      logger.error("Manage subscriptions failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// The store has charged, but the family's plan is whatever the server's webhook has written, so wait for that
  /// rather than trusting the SDK: the server decides who can write.
  private func confirmPlan() async {
    for attempt in 0..<pollAttempts {
      await entitlements.load(familyUnitId: familyUnitId())
      if entitlements.subscription?.status == .active {
        didActivate = true
        notice = nil
        return
      }
      if attempt < pollAttempts - 1 { await sleep(pollInterval) }
    }
    notice = .settingUp
  }
}
