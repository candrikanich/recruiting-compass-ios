import Foundation

/// Feature-local composition root. Wires Data → Domain → Presentation
/// so views never construct `SchoolsRepositoryImpl` or `.shared` graphs.
enum SchoolsFactory {

  static func makeRepository(
    supabaseManager: SupabaseManager = .shared
  ) -> any SchoolsRepository {
    SchoolsRepositoryImpl(supabaseManager: supabaseManager)
  }

  @MainActor
  static func makeListViewModel(
    schoolsService: (any SchoolsManaging)? = nil,
    familyManager: FamilyManager? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    interactionsService: (any InteractionsManaging)? = nil,
    eventsService: (any EventsManaging)? = nil,
    cache: (any CacheManaging)? = nil
  ) -> SchoolsListViewModel {
    let repository = schoolsService ?? makeRepository()
    return SchoolsListViewModel(
      schoolsService: repository,
      familyManager: familyManager,
      preferenceService: preferenceService,
      authManager: authManager,
      interactionsService: interactionsService,
      eventsService: eventsService,
      cache: cache,
      deleteSchool: DeleteSchoolUseCase(repository: repository)
    )
  }

  @MainActor
  static func makeDetailViewModel(
    schoolId: String,
    schoolsService: (any SchoolsManaging)? = nil,
    authManager: (any AuthManaging)? = nil,
    familyManager: FamilyManager? = nil,
    collegeService: (any CollegeScorecardManaging)? = nil,
    coachesService: (any CoachesManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil,
    enrichService: (any SchoolEnriching)? = nil,
    cache: (any CacheManaging)? = nil
  ) -> SchoolDetailViewModel {
    SchoolDetailViewModel(
      schoolId: schoolId,
      schoolsService: schoolsService ?? makeRepository(),
      authManager: authManager,
      familyManager: familyManager,
      collegeService: collegeService,
      coachesService: coachesService,
      preferenceService: preferenceService,
      enrichService: enrichService,
      cache: cache
    )
  }

  @MainActor
  static func makeAddViewModel(
    schoolsService: any SchoolsManaging,
    familyUnitId: String,
    userId: String
  ) -> AddSchoolViewModel {
    AddSchoolViewModel(
      schoolsService: schoolsService,
      familyUnitId: familyUnitId,
      userId: userId
    )
  }
}
