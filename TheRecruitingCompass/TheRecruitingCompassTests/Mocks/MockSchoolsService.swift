import Foundation
@testable import TheRecruitingCompass

final class MockSchoolsService: SchoolsManaging, @unchecked Sendable {
  // Call counters
  var fetchSchoolsCallCount = 0
  var fetchSchoolCallCount = 0
  var deleteSchoolCallCount = 0
  var cascadeDeleteSchoolCallCount = 0
  var toggleFavoriteCallCount = 0
  var updateStatusCallCount = 0
  var fetchStatusHistoryCallCount = 0

  // Phase 2 call counters
  var updateNotesCallCount = 0
  var updatePrivateNotesCallCount = 0
  var addProCallCount = 0
  var removeProCallCount = 0
  var addConCallCount = 0
  var removeConCallCount = 0
  var updateBasicInfoCallCount = 0

  // Stubbed data
  var stubbedSchools: [School] = []
  var stubbedSchool: School?
  var stubbedStatusHistory: [SchoolStatusHistory] = []
  var shouldThrowError = false
  var errorToThrow: Error = NSError(domain: "MockSchoolsService", code: -1)
  var stubbedDeleteResult = DeleteResult(isCascadeUsed: true, deletedInteractions: 2, deletedNotes: 1)

  // Phase 2 tracking
  var lastUpdatedNotes: String?
  var lastUpdatedPrivateNote: String?
  var lastPrivateNoteUserId: String?
  var lastAddedPro: String?
  var lastRemovedProIndex: Int?
  var lastAddedCon: String?
  var lastRemovedConIndex: Int?
  var lastUpdatedBasicInfo: EditableBasicInfo?

  func fetchSchools(familyUnitId: String) async throws -> [School] {
    fetchSchoolsCallCount += 1
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedSchools
  }

  func deleteSchool(id: String) async throws {
    deleteSchoolCallCount += 1
    if shouldThrowError {
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
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
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
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    stubbedSchool = school.with(notes: notes)
    return stubbedSchool!
  }

  func updatePrivateNotes(id: String, familyUnitId: String, userId: String, note: String?) async throws -> School {
    updatePrivateNotesCallCount += 1
    lastUpdatedPrivateNote = note
    lastPrivateNoteUserId = userId
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var privateNotes = school.privateNotes ?? [:]
    if let note = note {
      privateNotes[userId] = note
    } else {
      privateNotes.removeValue(forKey: userId)
    }
    stubbedSchool = school.with(privateNotes: privateNotes)
    return stubbedSchool!
  }

  func addPro(id: String, familyUnitId: String, text: String) async throws -> School {
    addProCallCount += 1
    lastAddedPro = text
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var pros = school.pros
    pros.append(text)
    stubbedSchool = school.with(pros: pros)
    return stubbedSchool!
  }

  func removePro(id: String, familyUnitId: String, index: Int) async throws -> School {
    removeProCallCount += 1
    lastRemovedProIndex = index
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
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
    guard var school = stubbedSchool else {
      throw NSError(domain: "MockSchoolsService", code: -1)
    }
    var cons = school.cons
    cons.append(text)
    stubbedSchool = school.with(cons: cons)
    return stubbedSchool!
  }

  func removeCon(id: String, familyUnitId: String, index: Int) async throws -> School {
    removeConCallCount += 1
    lastRemovedConIndex = index
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
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

  func updateBasicInfo(id: String, info: EditableBasicInfo) async throws -> School {
    updateBasicInfoCallCount += 1
    lastUpdatedBasicInfo = info
    if shouldThrowError {
      throw errorToThrow
    }
    guard var school = stubbedSchool else {
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
    // Merge college data into academic info
    let updatedInfo = AcademicInfo(
      gpaRequirement: school.academicInfo?.gpaRequirement,
      satRequirement: school.academicInfo?.satRequirement,
      actRequirement: school.academicInfo?.actRequirement,
      additionalRequirements: school.academicInfo?.additionalRequirements,
      address: data.address ?? school.academicInfo?.address,
      city: data.city ?? school.academicInfo?.city,
      state: data.state ?? school.academicInfo?.state,
      latitude: data.latitude ?? school.academicInfo?.latitude,
      longitude: data.longitude ?? school.academicInfo?.longitude,
      studentSize: data.studentSize ?? school.academicInfo?.studentSize,
      baseballFacilityAddress: school.academicInfo?.baseballFacilityAddress,
      mascot: school.academicInfo?.mascot,
      undergradSize: data.carnegieSize ?? school.academicInfo?.undergradSize,
      carnegieSize: data.carnegieSize ?? school.academicInfo?.carnegieSize,
      tuitionInState: data.tuitionInState ?? school.academicInfo?.tuitionInState,
      tuitionOutOfState: data.tuitionOutOfState ?? school.academicInfo?.tuitionOutOfState,
      admissionRate: data.admissionRate ?? school.academicInfo?.admissionRate,
      distanceFromHome: school.academicInfo?.distanceFromHome
    )
    stubbedSchool = school.with(academicInfo: updatedInfo)
    return stubbedSchool!
  }
}
