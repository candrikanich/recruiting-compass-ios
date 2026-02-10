import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "SchoolsService")

final class SchoolsServiceImpl: SchoolsManaging, @unchecked Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  private func fetch<T: Decodable>(
    _ label: String,
    query: () async throws -> [T]
  ) async throws -> [T] {
    logger.debug("Fetching \(label)")
    do {
      let result = try await query()
      logger.info("Fetched \(result.count) \(label)")
      return result
    } catch {
      logger.error("Failed to fetch \(label): \(error.localizedDescription)")
      if let decodingError = error as? DecodingError {
        logger.error("Decoding error: \(String(describing: decodingError))")
      }
      throw error
    }
  }

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    try await fetch("schools") {
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

    let now = Date()
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
    try await fetch("status history") {
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

  func updatePrivateNotes(id: String, familyUnitId: String, userId: String, note: String?) async throws -> School {
    logger.debug("Updating private notes for school: \(id), user: \(userId)")

    // CRITICAL: Fetch current school to merge private notes
    let current = try await fetchSchool(id: id, familyUnitId: familyUnitId)
    var privateNotes = current.privateNotes ?? [:]

    if let note = note, !note.isEmpty {
      privateNotes[userId] = note
    } else {
      privateNotes.removeValue(forKey: userId)
    }

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["private_notes": privateNotes])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Private notes updated for school: \(id)")
    return updated
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

  func updateBasicInfo(id: String, info: EditableBasicInfo) async throws -> School {
    logger.debug("Updating basic info for school: \(id)")

    // Build update dictionary with non-empty values only
    var update: [String: String] = [:]

    if !info.website.isEmpty {
      update["website"] = info.website
    }
    if !info.twitterHandle.isEmpty {
      update["twitter_handle"] = info.twitterHandle
    }
    if !info.instagramHandle.isEmpty {
      update["instagram_handle"] = info.instagramHandle
    }

    // For academic_info nested fields, build a JSON object
    var academicInfo: [String: String] = [:]
    if !info.address.isEmpty {
      academicInfo["address"] = info.address
    }
    if !info.baseballFacilityAddress.isEmpty {
      academicInfo["baseball_facility_address"] = info.baseballFacilityAddress
    }
    if !info.mascot.isEmpty {
      academicInfo["mascot"] = info.mascot
    }
    if !info.undergradSize.isEmpty {
      academicInfo["undergrad_size"] = info.undergradSize
    }

    // Add academic_info as JSON if there are updates
    if !academicInfo.isEmpty {
      if let jsonData = try? JSONSerialization.data(withJSONObject: academicInfo),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        update["academic_info"] = jsonString
      }
    }

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(update)
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Basic info updated for school: \(id)")
    return updated
  }

  // MARK: - Phase 3: College Data Merge

  func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School {
    logger.debug("Merging college data for school: \(id)")

    // Build academic_info update from college data
    var academicInfo: [String: Any] = [:]

    if let city = data.city {
      academicInfo["city"] = city
    }
    if let state = data.state {
      academicInfo["state"] = state
    }
    if let address = data.address {
      academicInfo["address"] = address
    }
    if let lat = data.latitude {
      academicInfo["latitude"] = lat
    }
    if let lon = data.longitude {
      academicInfo["longitude"] = lon
    }
    if let studentSize = data.studentSize {
      academicInfo["student_size"] = studentSize
    }
    if let carnegieSize = data.carnegieSize {
      academicInfo["carnegie_size"] = carnegieSize
    }
    if let undergradSize = data.studentSize {
      // Convert Int to String for undergrad_size field
      academicInfo["undergrad_size"] = String(undergradSize)
    }
    if let tuitionIn = data.tuitionInState {
      academicInfo["tuition_in_state"] = tuitionIn
    }
    if let tuitionOut = data.tuitionOutOfState {
      academicInfo["tuition_out_of_state"] = tuitionOut
    }
    if let admissionRate = data.admissionRate {
      academicInfo["admission_rate"] = admissionRate
    }

    // Convert to JSON string for Supabase
    guard let jsonData = try? JSONSerialization.data(withJSONObject: academicInfo),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw SchoolError.invalidData
    }

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["academic_info": jsonString])
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

  // MARK: - Phase 4: Priority Tier

  func updatePriorityTier(id: String, tier: PriorityTier?) async throws -> School {
    logger.debug("Updating priority tier for school: \(id) to \(tier?.rawValue ?? "none")")

    let tierValue: String? = tier?.rawValue

    let updated: School = try await supabaseManager.client
      .from("schools")
      .update(["priority_tier": tierValue])
      .eq("id", value: id)
      .select()
      .single()
      .execute()
      .value

    logger.info("Priority tier updated for school: \(id)")
    return updated
  }
}
