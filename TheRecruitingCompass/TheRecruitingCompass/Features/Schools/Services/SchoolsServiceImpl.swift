import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolsService")

/// Sendable: Stateless service with no mutable properties
final class SchoolsServiceImpl: SchoolsManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  // MARK: - Create

  func createSchool(request: SchoolCreateRequest) async throws -> School {
    logger.debug("Creating school: \(request.name)")

    // Build insert payload including top-level city/state (migration adds these columns).
    // Also merge city/state into academic_info for backward compatibility.
    let payload = SchoolsInsertPayload(from: request)

    let result: School = try await supabaseManager.client
      .from("schools")
      .insert(payload)
      .select()
      .single()
      .execute()
      .value

    logger.info("School created: \(result.id)")
    return result
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await logger.fetch("schools") {
      try await supabaseManager.client
        .from("schools")
        .select()
        .eq("family_unit_id", value: familyUnitId)
        .order("name")
        .execute()
        .value
    }
  }

  func deleteSchool(id: String) async throws {
    logger.debug("Deleting school: \(id)")
    try await supabaseManager.client
      .from("schools")
      .delete()
      .eq("id", value: id)
      .execute()
    logger.info("School deleted: \(id)")
  }

  func cascadeDeleteSchool(id: String) async throws -> DeleteResult {
    logger.debug("Cascade deleting school: \(id)")
    let result: DeleteResult = try await supabaseManager.client
      .rpc("cascade_delete_school", params: ["school_id": id])
      .execute()
      .value
    logger.info("Cascade delete complete for school: \(id)")
    return result
  }

  func toggleFavorite(id: String, isFavorite: Bool) async throws {
    logger.debug("Toggling favorite for school: \(id) to \(isFavorite)")
    try await supabaseManager.client
      .from("schools")
      .update(["is_favorite": isFavorite])
      .eq("id", value: id)
      .execute()
    logger.info("School favorite toggled: \(id)")
  }

  func fetchSchool(id: String, familyUnitId: String) async throws -> School {
    logger.debug("Fetching single school: \(id)")
    do {
      let school: School = try await supabaseManager.client
        .from("schools")
        .select()
        .eq("id", value: id)
        .eq("family_unit_id", value: familyUnitId)
        .single()
        .execute()
        .value
      logger.info("Fetched school: \(school.name)")
      return school
    } catch {
      logger.error("Failed to fetch school: \(error.localizedDescription)")
      throw error
    }
  }

  func updateStatus(
    id: String,
    newStatus: SchoolStatus,
    previousStatus: SchoolStatus,
    userId: String
  ) async throws -> School {
    logger.debug("Updating school status: \(id) from \(previousStatus.rawValue) to \(newStatus.rawValue)")

    let now = Date.now
    let iso8601Formatter = ISO8601DateFormatter()
    iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // 1. Update school status
    let updatedSchool: School = try await supabaseManager.client
      .from("schools")
      .update([
        "status": newStatus.rawValue,
        "status_changed_at": iso8601Formatter.string(from: now),
        "updated_by": userId
      ])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    // 2. Create history entry
    try await supabaseManager.client
      .from("school_status_history")
      .insert([
        "school_id": id,
        "previous_status": previousStatus.rawValue,
        "new_status": newStatus.rawValue,
        "changed_by": userId,
        "changed_at": iso8601Formatter.string(from: now)
      ])
      .execute()

    logger.info("School status updated and history created for: \(id)")
    return updatedSchool
  }

  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory] {
    try await logger.fetch("status history") {
      try await supabaseManager.client
        .from("school_status_history")
        .select()
        .eq("school_id", value: schoolId)
        .order("changed_at", ascending: false)
        .execute()
        .value
    }
  }

  // MARK: - Phase 2 Methods (Editing & Notes)

  func updateNotes(id: String, notes: String) async throws -> School {
    logger.debug("Updating notes for school: \(id)")

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["notes": notes])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Notes updated for school: \(id)")
    return updated
  }

  func fetchOutreachNotes(id: String) async throws -> SchoolOutreachNotes {
    let notes: SchoolOutreachNotes = try await supabaseManager.client
      .from("schools")
      .select("why_program, fit_reason")
      .eq("id", value: id)
      .single()
      .execute()
      .value
    return notes
  }

  func updateOutreachNotes(id: String, whyProgram: String?, fitReason: String?) async throws {
    struct OutreachUpdate: Encodable { let why_program: String?; let fit_reason: String? }
    logger.debug("Updating outreach notes for school: \(id)")
    _ = try await supabaseManager.client
      .from("schools")
      .update(OutreachUpdate(why_program: whyProgram, fit_reason: fitReason))
      .eq("id", value: id)
      .execute()
    logger.info("Outreach notes updated for school: \(id)")
  }

  func updateQuestionnaireCompleted(id: String, completed: Bool) async throws {
    struct QuestionnaireUpdate: Encodable {
      let questionnaire_completed: Bool
      let questionnaire_completed_at: String?
    }
    let timestamp = completed ? ISO8601DateFormatter().string(from: Date()) : nil
    logger.debug("Updating questionnaire_completed for school: \(id) to \(completed)")
    _ = try await supabaseManager.client
      .from("schools")
      .update(QuestionnaireUpdate(questionnaire_completed: completed, questionnaire_completed_at: timestamp))
      .eq("id", value: id)
      .execute()
    logger.info("Questionnaire completion updated for school: \(id)")
  }

  func addPro(id: String, familyUnitId: String, text: String) async throws -> School {
    logger.debug("Adding pro to school: \(id)")

    // Fetch current school to append to array
    let current = try await fetchSchool(id: id, familyUnitId: familyUnitId)
    var pros = current.pros
    pros.append(text)

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["pros": pros])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Pro added to school: \(id)")
    return updated
  }

  func removePro(id: String, familyUnitId: String, index: Int) async throws -> School {
    logger.debug("Removing pro at index \(index) from school: \(id)")

    let current = try await fetchSchool(id: id, familyUnitId: familyUnitId)
    var pros = current.pros
    guard index < pros.count else {
      logger.error("Invalid pro index: \(index) for school: \(id)")
      throw SchoolError.invalidIndex
    }
    pros.remove(at: index)

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["pros": pros])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Pro removed from school: \(id)")
    return updated
  }

  func addCon(id: String, familyUnitId: String, text: String) async throws -> School {
    logger.debug("Adding con to school: \(id)")

    let current = try await fetchSchool(id: id, familyUnitId: familyUnitId)
    var cons = current.cons
    cons.append(text)

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["cons": cons])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Con added to school: \(id)")
    return updated
  }

  func removeCon(id: String, familyUnitId: String, index: Int) async throws -> School {
    logger.debug("Removing con at index \(index) from school: \(id)")

    let current = try await fetchSchool(id: id, familyUnitId: familyUnitId)
    var cons = current.cons
    guard index < cons.count else {
      logger.error("Invalid con index: \(index) for school: \(id)")
      throw SchoolError.invalidIndex
    }
    cons.remove(at: index)

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["cons": cons])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Con removed from school: \(id)")
    return updated
  }

  func updateBasicInfo(
    id: String,
    info: EditableBasicInfo,
    existingAcademicInfo: AcademicInfo?
  ) async throws -> School {
    logger.debug("Updating basic info for school: \(id)")

    // Empty string means the user cleared the field → store null. The form is
    // pre-populated from the school, so an unchanged field carries its value.
    func nilIfEmpty(_ value: String) -> String? {
      value.isEmpty ? nil : value
    }

    // Merge the edited address into the existing academic_info so lookup-populated
    // fields (lat/long, tuition, student_size, …) are preserved rather than wiped.
    let mergedAcademicInfo = mergeAddress(
      into: existingAcademicInfo,
      address: nilIfEmpty(info.address)
    )

    let payload = BasicInfoUpdatePayload(
      website: nilIfEmpty(info.website),
      athletics_url: nilIfEmpty(info.athleticsUrl),
      twitter_handle: nilIfEmpty(info.twitterHandle),
      instagram_handle: nilIfEmpty(info.instagramHandle),
      phone: nilIfEmpty(info.phone),
      academic_info: mergedAcademicInfo
    )

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(payload)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Basic info updated for school: \(id)")
    return updated
  }

  /// Returns a copy of `existing` with `address` overridden, preserving every
  /// other academic_info field. Returns nil only when there is nothing to store.
  private func mergeAddress(into existing: AcademicInfo?, address: String?) -> AcademicInfo? {
    guard existing != nil || address != nil else { return nil }
    return AcademicInfo(
      gpaRequirement: existing?.gpaRequirement,
      satRequirement: existing?.satRequirement,
      actRequirement: existing?.actRequirement,
      additionalRequirements: existing?.additionalRequirements,
      address: address ?? existing?.address,
      city: existing?.city,
      state: existing?.state,
      latitude: existing?.latitude,
      longitude: existing?.longitude,
      studentSize: existing?.studentSize,
      baseballFacilityAddress: existing?.baseballFacilityAddress,
      mascot: existing?.mascot,
      undergradSize: existing?.undergradSize,
      carnegieSize: existing?.carnegieSize,
      tuitionInState: existing?.tuitionInState,
      tuitionOutOfState: existing?.tuitionOutOfState,
      admissionRate: existing?.admissionRate,
      distanceFromHome: existing?.distanceFromHome
    )
  }

  // MARK: - Phase 3: College Data Merge

  func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School {
    logger.debug("Merging college data for school: \(id)")

    // Send academic_info as a JSON object (not a string) so the DB stores JSONB and returns
    // an object; otherwise decoding School.academicInfo fails ("isn't in the correct format").
    let payload = CollegeDataMergePayload(
      academic_info: AcademicInfoMergePayload(
        city: data.city,
        state: data.state,
        address: data.address,
        latitude: data.latitude,
        longitude: data.longitude,
        student_size: data.studentSize,
        carnegie_size: data.carnegieSize,
        undergrad_size: data.studentSize.map { String($0) },
        tuition_in_state: data.tuitionInState,
        tuition_out_of_state: data.tuitionOutOfState,
        admission_rate: data.admissionRate
      )
    )

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(payload)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("College data merged for school: \(id)")
    return updated
  }

  // MARK: - Phase 4: Coaching Philosophy

  func updateCoachingPhilosophy(id: String, philosophy: EditableCoachingPhilosophy) async throws -> School {
    logger.debug("Updating coaching philosophy for school: \(id)")

    var updates: [String: String?] = [:]
    updates["coaching_philosophy"] = philosophy.coachingPhilosophy.isEmpty ? nil : philosophy.coachingPhilosophy
    updates["coaching_style"] = philosophy.coachingStyle.isEmpty ? nil : philosophy.coachingStyle
    updates["recruiting_approach"] = philosophy.recruitingApproach.isEmpty ? nil : philosophy.recruitingApproach
    updates["communication_style"] = philosophy.communicationStyle.isEmpty ? nil : philosophy.communicationStyle
    updates["success_metrics"] = philosophy.successMetrics.isEmpty ? nil : philosophy.successMetrics

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(updates)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Coaching philosophy updated for school: \(id)")
    return updated
  }

}

// MARK: - School Insert Payload

/// Insert payload including top-level city/state (schools table has these columns per migration).
/// Also merges city/state into academic_info for backward compatibility.
private struct SchoolsInsertPayload: Encodable {
  let user_id: String
  let family_unit_id: String
  let name: String
  let location: String?
  let city: String?
  let state: String?
  let division: String?
  let conference: String?
  let website: String?
  let twitter_handle: String?
  let instagram_handle: String?
  let ncaa_id: String?
  let notes: String?
  let status: String
  let academic_info: AcademicInfo?
  let favicon_url: String?

  init(from request: SchoolCreateRequest) {
    user_id = request.userId
    family_unit_id = request.familyUnitId
    name = request.name
    location = request.location
    city = request.city
    state = request.state
    division = request.division
    conference = request.conference
    website = request.website
    twitter_handle = request.twitterHandle
    instagram_handle = request.instagramHandle
    ncaa_id = request.ncaaId
    notes = request.notes
    status = request.status
    favicon_url = request.faviconUrl
    // Merge city/state from request into academic_info
    let base = request.academicInfo
    if request.city != nil || request.state != nil || base != nil {
      academic_info = AcademicInfo(
        gpaRequirement: base?.gpaRequirement,
        satRequirement: base?.satRequirement,
        actRequirement: base?.actRequirement,
        additionalRequirements: base?.additionalRequirements,
        address: base?.address,
        city: request.city ?? base?.city,
        state: request.state ?? base?.state,
        latitude: base?.latitude,
        longitude: base?.longitude,
        studentSize: base?.studentSize,
        baseballFacilityAddress: base?.baseballFacilityAddress,
        mascot: base?.mascot,
        undergradSize: base?.undergradSize,
        carnegieSize: base?.carnegieSize,
        tuitionInState: base?.tuitionInState,
        tuitionOutOfState: base?.tuitionOutOfState,
        admissionRate: base?.admissionRate,
        distanceFromHome: base?.distanceFromHome
      )
    } else {
      academic_info = nil
    }
  }
}

// MARK: - College Data Merge Payloads

/// Contact & Social update. Nil fields are omitted (patch semantics — a cleared
/// field keeps its prior value); academic_info is sent as a JSON object so JSONB
/// stores it correctly and the returned School decodes.
private struct BasicInfoUpdatePayload: Encodable {
  let website: String?
  let athletics_url: String?
  let twitter_handle: String?
  let instagram_handle: String?
  let phone: String?
  let academic_info: AcademicInfo?

  enum CodingKeys: String, CodingKey {
    case website
    case athletics_url
    case twitter_handle
    case instagram_handle
    case phone
    case academic_info
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(website, forKey: .website)
    try c.encodeIfPresent(athletics_url, forKey: .athletics_url)
    try c.encodeIfPresent(twitter_handle, forKey: .twitter_handle)
    try c.encodeIfPresent(instagram_handle, forKey: .instagram_handle)
    try c.encodeIfPresent(phone, forKey: .phone)
    try c.encodeIfPresent(academic_info, forKey: .academic_info)
  }
}

/// Encodable payload so academic_info is sent as a JSON object (not a string); required for JSONB and for decoding the updated School.
private struct CollegeDataMergePayload: Encodable {
  let academic_info: AcademicInfoMergePayload
}

private struct AcademicInfoMergePayload: Encodable {
  let city: String?
  let state: String?
  let address: String?
  let latitude: Double?
  let longitude: Double?
  let student_size: Int?
  let carnegie_size: String?
  let undergrad_size: String?
  let tuition_in_state: Double?
  let tuition_out_of_state: Double?
  let admission_rate: Double?

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(city, forKey: .city)
    try c.encodeIfPresent(state, forKey: .state)
    try c.encodeIfPresent(address, forKey: .address)
    try c.encodeIfPresent(latitude, forKey: .latitude)
    try c.encodeIfPresent(longitude, forKey: .longitude)
    try c.encodeIfPresent(student_size, forKey: .student_size)
    try c.encodeIfPresent(carnegie_size, forKey: .carnegie_size)
    try c.encodeIfPresent(undergrad_size, forKey: .undergrad_size)
    try c.encodeIfPresent(tuition_in_state, forKey: .tuition_in_state)
    try c.encodeIfPresent(tuition_out_of_state, forKey: .tuition_out_of_state)
    try c.encodeIfPresent(admission_rate, forKey: .admission_rate)
  }

  enum CodingKeys: String, CodingKey {
    case city, state, address, latitude, longitude
    case student_size, carnegie_size, undergrad_size
    case tuition_in_state, tuition_out_of_state, admission_rate
  }
}
