import Foundation
@testable import TheRecruitingCompass

final class MockSchoolsService: SchoolsManaging, @unchecked Sendable {
  // Call counters
  var createSchoolCallCount = 0
  var fetchSchoolsCallCount = 0
  var fetchSchoolCallCount = 0
  var deleteSchoolCallCount = 0
  var cascadeDeleteSchoolCallCount = 0
  var toggleFavoriteCallCount = 0
  var updateStatusCallCount = 0
  var fetchStatusHistoryCallCount = 0

  // Phase 2 call counters
  var updateNotesCallCount = 0
  var addProCallCount = 0
  var removeProCallCount = 0
  var addConCallCount = 0
  var removeConCallCount = 0
  var updateBasicInfoCallCount = 0

  // Stubbed data
  var stubbedCreatedSchool: School?
  var stubbedSchools: [School] = []
  var stubbedSchool: School?
  var stubbedStatusHistory: [SchoolStatusHistory] = []
  var shouldThrowError = false
  var errorToThrow: Error = NSError(domain: "MockSchoolsService", code: -1)
  var stubbedDeleteResult = DeleteResult(isCascadeUsed: true, deletedInteractions: 2, deletedNotes: 1)

  // Phase 2 tracking
  var lastUpdatedNotes: String?
  var lastAddedPro: String?
  var lastProIndex: Int? // Alias for lastRemovedProIndex
  var lastRemovedProIndex: Int?
  var lastConIndex: Int? // Alias for lastRemovedConIndex
  var lastAddedCon: String?
  var lastRemovedConIndex: Int?
  var lastUpdatedBasicInfo: EditableBasicInfo?

  // Phase 4 tracking
  var updateCoachingPhilosophyCallCount = 0
  var lastUpdatedPhilosophy: EditableCoachingPhilosophy?
  var shouldSucceed = true
  var simpleDeleteShouldFail = false

  var delayDuration: TimeInterval = 0

  // MARK: - Create

  func createSchool(request: SchoolCreateRequest) async throws -> School {
    createSchoolCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedCreatedSchool else {
      fatalError("stubbedCreatedSchool must be set for createSchool tests")
    }
    return school
  }

  // MARK: - Fetch

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedSchools
  }

  func deleteSchool(id: String) async throws {
    deleteSchoolCallCount += 1
    if shouldThrowError || simpleDeleteShouldFail {
      throw errorToThrow
    }
  }

  func cascadeDeleteSchool(id: String) async throws -> DeleteResult {
    cascadeDeleteSchoolCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedDeleteResult
  }

  func toggleFavorite(id: String, isFavorite: Bool) async throws {
    toggleFavoriteCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
  }

  // MARK: - Phase 1 Methods

  func fetchSchool(id: String, familyUnitId: String) async throws -> School {
    fetchSchoolCallCount += 1
    if delayDuration > 0 {
      try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
    }
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No stubbed school"])
    }
    return school
  }

  func updateStatus(
    id: String,
    newStatus: SchoolStatus,
    previousStatus: SchoolStatus,
    userId: String
  ) async throws -> School {
    updateStatusCallCount += 1
    if delayDuration > 0 {
      try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
    }
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    // Update the school's status
    stubbedSchool = school.with(status: newStatus.rawValue)
    return stubbedSchool!
  }

  func fetchStatusHistory(schoolId: String) async throws -> [SchoolStatusHistory] {
    fetchStatusHistoryCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedStatusHistory
  }

  // MARK: - Phase 2 Methods

  func updateNotes(id: String, notes: String) async throws -> School {
    updateNotesCallCount += 1
    lastUpdatedNotes = notes
    if delayDuration > 0 {
      try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
    }
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    stubbedSchool = school.with(notes: notes)
    return stubbedSchool!
  }

  func addPro(id: String, familyUnitId: String, text: String) async throws -> School {
    addProCallCount += 1
    lastAddedPro = text
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var pros = school.pros
    pros.append(text)
    stubbedSchool = school.with(pros: pros)
    return stubbedSchool!
  }

  func removePro(id: String, familyUnitId: String, index: Int) async throws -> School {
    removeProCallCount += 1
    lastProIndex = index
    lastRemovedProIndex = index
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var pros = school.pros
    guard index < pros.count else {
      throw SchoolError.invalidIndex
    }
    pros.remove(at: index)
    stubbedSchool = school.with(pros: pros)
    return stubbedSchool!
  }

  func addCon(id: String, familyUnitId: String, text: String) async throws -> School {
    addConCallCount += 1
    lastAddedCon = text
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var cons = school.cons
    cons.append(text)
    stubbedSchool = school.with(cons: cons)
    return stubbedSchool!
  }

  func removeCon(id: String, familyUnitId: String, index: Int) async throws -> School {
    removeConCallCount += 1
    lastConIndex = index
    lastRemovedConIndex = index
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var cons = school.cons
    guard index < cons.count else {
      throw SchoolError.invalidIndex
    }
    cons.remove(at: index)
    stubbedSchool = school.with(cons: cons)
    return stubbedSchool!
  }

  func updateBasicInfo(
    id: String,
    info: EditableBasicInfo,
    existingAcademicInfo: AcademicInfo?
  ) async throws -> School {
    updateBasicInfoCallCount += 1
    lastUpdatedBasicInfo = info
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    // Update school with basic info
    stubbedSchool = school.with(website: info.website)
    return stubbedSchool!
  }

  func mergeCollegeData(id: String, data: CollegeDataResult) async throws -> School {
    if shouldThrowError {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    // For mock purposes, just return the school unchanged
    // Real implementation would merge college data
    return school
  }

  // MARK: - Phase 4 Methods

  func updateCoachingPhilosophy(id: String, philosophy: EditableCoachingPhilosophy) async throws -> School {
    updateCoachingPhilosophyCallCount += 1
    lastUpdatedPhilosophy = philosophy
    if shouldThrowError || !shouldSucceed {
      throw errorToThrow
    }
    guard let school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    // Create a new school with updated coaching philosophy fields
    stubbedSchool = School(
      id: school.id,
      userId: school.userId,
      name: school.name,
      location: school.location,
      city: school.city,
      state: school.state,
      division: school.division,
      conference: school.conference,
      ranking: school.ranking,
      isFavorite: school.isFavorite,
      website: school.website,
      faviconUrl: school.faviconUrl,
      twitterHandle: school.twitterHandle,
      instagramHandle: school.instagramHandle,
      ncaaId: school.ncaaId,
      status: school.status,
      statusChangedAt: school.statusChangedAt,
      notes: school.notes,
      pros: school.pros,
      cons: school.cons,
      offerDetails: school.offerDetails,
      academicInfo: school.academicInfo,
      amenities: school.amenities,
      coachingPhilosophy: philosophy.coachingPhilosophy.isEmpty ? nil : philosophy.coachingPhilosophy,
      coachingStyle: philosophy.coachingStyle.isEmpty ? nil : philosophy.coachingStyle,
      recruitingApproach: philosophy.recruitingApproach.isEmpty ? nil : philosophy.recruitingApproach,
      communicationStyle: philosophy.communicationStyle.isEmpty ? nil : philosophy.communicationStyle,
      successMetrics: philosophy.successMetrics.isEmpty ? nil : philosophy.successMetrics,
      familyUnitId: school.familyUnitId,
      createdBy: school.createdBy,
      updatedBy: school.updatedBy,
      createdAt: school.createdAt,
      updatedAt: school.updatedAt
    )
    return stubbedSchool!
  }

}
