import Foundation

/// A user-created recruiting deadline. RLS on `user_deadlines` is family-scoped
/// (migration `20260902000000_family_shared_user_deadlines.sql`): every family
/// member can see/manage every other member's deadlines, matching the
/// VideoLinks/Events/Schools family-scoping pattern.
struct Deadline: Codable, Identifiable, Sendable, Equatable {
  let id: String
  let userId: String
  let familyUnitId: String
  let label: String
  let deadlineDate: String          // "YYYY-MM-DD" (DATE column)
  let category: DeadlineCategory
  let schoolId: String?
  let createdAt: Date?
  let updatedAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case label
    case deadlineDate = "deadline_date"
    case category
    case schoolId = "school_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}
