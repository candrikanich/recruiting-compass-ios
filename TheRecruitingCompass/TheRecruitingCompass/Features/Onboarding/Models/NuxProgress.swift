import Foundation

enum NuxChecklistKey: String, CaseIterable, Codable, Sendable {
  case sport
  case firstSchool = "first_school"
  case academics
  case firstCoach = "first_coach"
  case inviteFamily = "invite_family"
  case profile80 = "profile_80"
  case previewTemplate = "preview_template"
  case checkTimeline = "check_timeline"
}

struct NuxChecklistItem: Codable, Sendable {
  var completed: Bool
  var completedAt: Date?

  static let incomplete = NuxChecklistItem(completed: false, completedAt: nil)
}

struct NuxChecklist: Codable, Sendable {
  var items: [String: NuxChecklistItem]
  var dismissedAt: Date?
  /// Set the instant all checklist items are complete; cleared if completion regresses.
  /// Distinct from `dismissedAt`, which stays manual/permanent once the user dismisses.
  var allCompleteAt: Date?

  var completedCount: Int {
    NuxChecklistKey.allCases.filter { items[$0.rawValue]?.completed == true }.count
  }

  var percentage: Int {
    Int((Double(completedCount) / Double(NuxChecklistKey.allCases.count) * 100).rounded())
  }
}

/// Tracks when the player profile first reached 100% completeness, for the
/// 24h auto-hide banner. Cleared if completeness regresses below 100%.
struct NuxProfileCompletion: Codable, Sendable {
  var completedAt: Date?

  static let empty = NuxProfileCompletion(completedAt: nil)
}

struct NuxProgress: Codable, Sendable {
  var version: Int
  var checklist: NuxChecklist
  var firstVisits: [String: Date]
  var dismissals: [String: Date]
  var profileCompletion: NuxProfileCompletion

  static let empty = NuxProgress(
    version: 1,
    checklist: NuxChecklist(items: [:], dismissedAt: nil, allCompleteAt: nil),
    firstVisits: [:],
    dismissals: [:],
    profileCompletion: .empty
  )

  init(
    version: Int,
    checklist: NuxChecklist,
    firstVisits: [String: Date],
    dismissals: [String: Date],
    profileCompletion: NuxProfileCompletion = .empty
  ) {
    self.version = version
    self.checklist = checklist
    self.firstVisits = firstVisits
    self.dismissals = dismissals
    self.profileCompletion = profileCompletion
  }

  enum CodingKeys: String, CodingKey {
    case version, checklist, firstVisits, dismissals, profileCompletion
  }

  // Custom decode: old persisted rows (before `profileCompletion` existed) must
  // decode to `.empty` rather than throw a missing-key error.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    checklist = try container.decode(NuxChecklist.self, forKey: .checklist)
    firstVisits = try container.decodeIfPresent([String: Date].self, forKey: .firstVisits) ?? [:]
    dismissals = try container.decodeIfPresent([String: Date].self, forKey: .dismissals) ?? [:]
    profileCompletion = try container.decodeIfPresent(NuxProfileCompletion.self, forKey: .profileCompletion) ?? .empty
  }

  func isItemCompleted(_ key: NuxChecklistKey) -> Bool {
    checklist.items[key.rawValue]?.completed == true
  }

  mutating func completeItem(_ key: NuxChecklistKey) {
    guard !isItemCompleted(key) else { return }
    checklist.items[key.rawValue] = NuxChecklistItem(completed: true, completedAt: Date())
  }

  func isPromptDismissed(_ key: String, cooldownDays: Int) -> Bool {
    guard let dismissedAt = dismissals[key] else { return false }
    return Date().timeIntervalSince(dismissedAt) < Double(cooldownDays) * 86_400
  }

  mutating func dismissPrompt(_ key: String) {
    dismissals[key] = Date()
  }

  /// Sets `checklist.allCompleteAt` the instant all items are complete (guarded so
  /// re-running with all-complete doesn't reset an existing timestamp); clears it
  /// if completion regresses.
  mutating func updateChecklistCompletion() {
    let allComplete = checklist.completedCount == NuxChecklistKey.allCases.count
    if allComplete {
      if checklist.allCompleteAt == nil {
        checklist.allCompleteAt = Date()
      }
    } else {
      checklist.allCompleteAt = nil
    }
  }

  /// Sets `profileCompletion.completedAt` the instant the profile reaches 100%
  /// (guarded against redundant writes); clears it if completeness regresses.
  mutating func updateProfileCompletion(percentage: Double) {
    if percentage >= 1.0 {
      if profileCompletion.completedAt == nil {
        profileCompletion.completedAt = Date()
      }
    } else {
      profileCompletion.completedAt = nil
    }
  }
}
