import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "BillingSession")

/// Keeps the purchase SDK's customer equal to the signed-in Supabase user. The webhook trusts the app user id the
/// SDK reports (web#1751), so it is only ever `auth.uid()`: never an anonymous id, never a guess.
///
/// Only a parent can buy (Chris, 2026-11-24), so only a parent is ever sent to the SDK: an athlete, often a minor,
/// creates no customer, and a missing role is not a parent. The server, not the SDK, grants family access, so nothing
/// an athlete sees reads the SDK.
@Observable
@MainActor
final class BillingSession {
  nonisolated deinit {}

  let purchases: any PurchasesProviding

  /// The user the SDK is logged in as, or nil while a login is pending, failed, or nobody is signed in.
  /// Purchases and restores wait on it.
  private(set) var identifiedUserId: String?

  private var latestSync = 0
  /// Read on every call: the role loads after sign-in, and a different user can sign in on the same device.
  private let role: () -> UserRole?

  init(purchases: any PurchasesProviding, role: @escaping () -> UserRole?) {
    self.purchases = purchases
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

  /// The user the SDK may know: only a parent. For anyone else this is nil, which detaches the SDK's customer.
  private func billableUserId(_ userId: String?) -> String? {
    role() == .parent ? userId : nil
  }

  /// Follows a sign-in, a switch of account, or a sign-out. Only the newest call may mark the session identified,
  /// so a slow login for an account the user has already left cannot unlock purchases for the next one.
  func sync(userId: String?) async {
    latestSync += 1
    let thisSync = latestSync
    identifiedUserId = nil
    do {
      if let userId = billableUserId(userId) {
        let appUserId = Self.appUserId(for: userId)
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
    guard let userId = billableUserId(userId) else { return false }
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
