import Foundation

/// The athlete's per-school outreach answers — "why this program" and "why it fits" —
/// stored on `schools` and used to prefill the coach-outreach template
/// (`{{programNote}}` / `{{fitReason}}`). Kept separate from the heavy `School` model so
/// prefill/save don't have to thread through its copy builders.
struct SchoolOutreachNotes: Codable, Sendable, Equatable {
  var whyProgram: String?
  var fitReason: String?

  var isEmpty: Bool {
    (whyProgram ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (fitReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  enum CodingKeys: String, CodingKey {
    case whyProgram = "why_program"
    case fitReason = "fit_reason"
  }
}
