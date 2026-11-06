import Foundation

/// Who may be offered marketing email (web #1066). Must agree with web's
/// `isMarketingEligible` and the server, which re-checks on every write.
enum MarketingEligibility {
  /// Parents are adults by role (no DOB is collected for them). Players qualify only when a
  /// known DOB makes them 18+; a missing DOB fails closed — the opposite of the under-13 gate.
  static func isEligible(
    role: UserRole?,
    dateOfBirth: Date?,
    now: Date = .now,
    calendar: Calendar = .current
  ) -> Bool {
    switch role {
    case .parent:
      return true
    case .player:
      guard let dateOfBirth else { return false }
      // Compare calendar days, like web's `ageFromDateOfBirth`: a DatePicker value keeps a
      // time-of-day, and a birthday later today must still count as 18.
      let age = COPPAHelper.age(
        fromDateOfBirth: calendar.startOfDay(for: dateOfBirth),
        now: calendar.startOfDay(for: now),
        calendar: calendar
      )
      return age >= COPPAHelper.adultAge
    case nil:
      return false
    }
  }
}
