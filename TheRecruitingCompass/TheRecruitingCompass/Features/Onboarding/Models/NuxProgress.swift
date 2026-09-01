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

  var completedCount: Int {
    NuxChecklistKey.allCases.filter { items[$0.rawValue]?.completed == true }.count
  }

  var percentage: Int {
    Int((Double(completedCount) / Double(NuxChecklistKey.allCases.count) * 100).rounded())
  }
}

struct NuxProgress: Codable, Sendable {
  var version: Int
  var checklist: NuxChecklist
  var firstVisits: [String: Date]
  var dismissals: [String: Date]

  static let empty = NuxProgress(
    version: 1,
    checklist: NuxChecklist(items: [:], dismissedAt: nil),
    firstVisits: [:],
    dismissals: [:]
  )

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
}
