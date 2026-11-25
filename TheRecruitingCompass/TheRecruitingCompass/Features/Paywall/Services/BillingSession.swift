import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "BillingSession")

/// Keeps the purchase SDK's customer equal to the signed-in Supabase user. The webhook trusts the app user id the
/// SDK reports (web#1751), so it is only ever `auth.uid()`: never an anonymous id, never a guess.
///
/// Only a parent can buy (Chris, 2026-11-24), so only a parent ever reaches the SDK, and the SDK does not start
/// until one signs in: its first call carries that parent's id, so no anonymous customer exists and RevenueCat
/// learns nothing about a device before then. An athlete, often a minor, a signed-out device, a missing role, a
/// build without a key and the `paywall` kill switch all leave the SDK stopped. The server, not the SDK, grants
/// family access, so nothing an athlete sees reads the SDK.
@Observable
@MainActor
final class BillingSession {
  nonisolated deinit {}

  let purchases: any PurchasesProviding

  /// The user the SDK is logged in as, or nil while a login is pending, failed, or nobody is signed in.
  /// Purchases and restores wait on it.
  private(set) var identifiedUserId: String?

  private var latestSync = 0
  /// Read on every call: the kill switch can flip while the app runs. Resolves only once the cold-launch flag
  /// refresh has finished (or timed out), so a switch the server has set is honoured before the SDK first starts.
  private let isPaywallEnabled: @MainActor () async -> Bool
  /// Read on every call: the role loads after sign-in, and a different user can sign in on the same device.
  private let role: () -> UserRole?

  init(
    purchases: any PurchasesProviding,
    isPaywallEnabled: @escaping @MainActor () async -> Bool,
    role: @escaping () -> UserRole?
  ) {
    self.purchases = purchases
    self.isPaywallEnabled = isPaywallEnabled
    self.role = role
  }

  /// Supabase reports `auth.uid()` in lowercase and the webhook compares it as text, so a Swift `uuidString`
  /// (uppercase) must never reach the SDK.
  static func appUserId(for userId: String) -> String {
    userId.lowercased()
  }

  func isIdentified(as userId: String?) -> Bool {
    guard let userId else { return false }
    return identifiedUserId == Self.appUserId(for: userId)
  }

  /// The user the SDK may know: only a parent, in a build that can sell, with the paywall on. For anyone else this
  /// is nil, which detaches a running SDK's customer and never starts a stopped one. The parent check comes first so
  /// an athlete never waits on the kill switch.
  private func billableUserId(_ userId: String?) async -> String? {
    guard role() == .parent, purchases.hasAPIKey, await isPaywallEnabled() else { return nil }
    return userId
  }

  /// Follows a sign-in, a switch of account, or a sign-out. Only the newest call may mark the session identified,
  /// so a slow login for an account the user has already left cannot unlock purchases for the next one.
  func sync(userId: String?) async {
    latestSync += 1
    let thisSync = latestSync
    identifiedUserId = nil
    do {
      let billableUserId = await billableUserId(userId)
      // The kill switch wait can outlast a sign-out or an account switch; only the newest sync may touch the SDK.
      guard thisSync == latestSync else { return }
      if let billableUserId {
        let appUserId = Self.appUserId(for: billableUserId)
        try await purchases.logIn(appUserId: appUserId)
        guard thisSync == latestSync else { return }
        identifiedUserId = appUserId
      } else {
        try await purchases.logOut()
      }
    } catch {
      logger.error("Billing identity sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// Retries a login that failed or never ran, so a purchase screen can recover without a relaunch.
  func ensureIdentified(as userId: String?) async -> Bool {
    guard let userId = await billableUserId(userId) else { return false }
    if isIdentified(as: userId) { return true }
    await sync(userId: userId)
    return isIdentified(as: userId)
  }

  /// The product this user's own subscription comes from, if they are the payer. Nil for anyone else.
  func currentProductId(as userId: String?) async -> String? {
    guard await ensureIdentified(as: userId) else { return nil }
    return try? await purchases.currentProductId()
  }
}
