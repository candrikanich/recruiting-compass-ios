import Foundation

/// Service contract for school CRUD operations, status management, and structured data editing.
///
/// Implementations fetch from and persist to the Supabase backend. Pass a mock conformance
/// to `SchoolDetailViewModel` to enable unit testing without network calls.
protocol SchoolsManaging: Sendable {
  // MARK: - Phase 0 Methods (Create)
  /// Creates a new school record and returns the persisted entity.
  func createSchool(request: SchoolCreateRequest) async throws -> School

  // MARK: - Phase 1 Methods
  /// Returns all schools belonging to the given family unit.
  func fetchSchools(familyUnitId: String) async throws -> [School]
  /// Returns a single school by ID, scoped to the given family unit.
  func fetchSchool(id: String, familyUnitId: String) async throws -> School
  /// Deletes the school record without cascading to related data.
  func deleteSchool(id: String) async throws
  /// Deletes the school and all associated coaches, interactions, and status history.
  func cascadeDeleteSchool(id: String) async throws -> DeleteResult
  /// Sets or clears the favourite flag on a school.
  func toggleFavorite(id: String, isFavorite: Bool) async throws
  /// Transitions the school to `newStatus`, recording the change in status history.
  func updateStatus(
    id: String,
    newStatus: SchoolStatus,
    previousStatus: SchoolStatus,
    userId: String
  ) async throws -> School
  /// Returns the full status-change history for a school, ordered newest-first.
  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory]
  /// Reopens a school from the `not_pursuing` off-ramp, restoring the stage it
  /// was at before it was parked (from status history) via the
  /// `reactivate_school` RPC, and returns the refreshed school.
  func reactivateSchool(id: String, familyUnitId: String, userId: String) async throws -> School

  // MARK: - Phase 2 Methods (Editing & Notes)
  /// Replaces the free-text notes on a school and returns the updated entity.
  func updateNotes(id: String, notes: String) async throws -> School
  /// Reads the per-school coach-outreach answers (why-program / why-fit).
  func fetchOutreachNotes(id: String) async throws -> SchoolOutreachNotes
  /// Saves the per-school coach-outreach answers (nil clears a field).
  func updateOutreachNotes(id: String, whyProgram: String?, fitReason: String?) async throws
  /// Marks whether the athlete completed this school's recruiting questionnaire.
  /// Gates the `{{questionnaireNote}}` line in coach-outreach templates.
  func updateQuestionnaireCompleted(id: String, completed: Bool) async throws
  /// Appends a pro to the school's pros list.
  func addPro(id: String, familyUnitId: String, text: String) async throws -> School
  /// Removes the pro at the given zero-based index from the school's pros list.
  func removePro(id: String, familyUnitId: String, index: Int) async throws -> School
  /// Appends a con to the school's cons list.
  func addCon(id: String, familyUnitId: String, text: String) async throws -> School
  /// Removes the con at the given zero-based index from the school's cons list.
  func removeCon(id: String, familyUnitId: String, index: Int) async throws -> School
  /// Updates the school's Contact & Social fields (address, phone, website, socials).
  /// `existingAcademicInfo` is merged so lookup-populated fields are preserved.
  func updateBasicInfo(
    id: String,
    info: EditableBasicInfo,
    existingAcademicInfo: AcademicInfo?
  ) async throws -> School

  // MARK: - Phase 3 Methods (College Data)
  /// Merges externally sourced college data (e.g. from a college-data API lookup) into the school record.
  func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School

  // MARK: - Phase 4 Methods (Coaching Philosophy)
  /// Saves the coaching philosophy fields edited by the user.
  func updateCoachingPhilosophy(id: String, philosophy: EditableCoachingPhilosophy) async throws -> School
}
