import SwiftUI

struct CoachFollowupWidget: View {
  let coaches: [Coach]
  /// All coaches tracked across the family's schools (unfiltered) — distinguishes
  /// "no coaches yet" from "caught up" for the empty-state CTA, mirroring web's
  /// `allCoachesData` (see `CoachFollowupWidget.vue`).
  let allCoaches: [Coach]
  let schools: [School]
  var familyUnitId: String = ""
  var userId: String = ""
  /// Reload the dashboard after a send so the just-contacted coach drops off this list.
  var onCoachContacted: (() -> Void)?

  @State private var quickCommContext: QuickCommunicationContext?
  @State private var didSendFromQuickComm = false
  @State private var profileCoachId: String?
  @State private var isShowingAllCoaches = false
  @State private var isShowingAddSchool = false
  @State private var isShowingAddCoach = false

  private var schoolNameMap: [String: String] { EntityNameLookup.schoolNameMap(from: schools) }

  private var emptyState: CoachFollowup.EmptyState? {
    CoachFollowup.emptyState(
      needsFollowupCount: coaches.count, allCoachesCount: allCoaches.count, allSchoolsCount: schools.count
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Coaches Needing Follow-up")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Spacer()
        if !coaches.isEmpty {
          Text("\(coaches.count)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentBlue.opacity(0.15))
            .clipShape(Capsule())
        }
      }

      Divider()

      switch emptyState {
      case .followASchool, .addACoach:
        onboardingCTA
      case .allCaughtUp:
        VStack(alignment: .leading, spacing: 2) {
          Text("🎉 All caught up!")
            .font(.subheadline.weight(.semibold))
          Text("No coaches need immediate follow-up")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical)
      case nil:
        let visible = Array(coaches.prefix(5))
        VStack(spacing: 8) {
          ForEach(visible) { coach in
            CoachFollowupRow(
              coach: coach,
              schoolName: EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap),
              onEmail: { presentQuickComm(coach) },
              onText: { presentQuickComm(coach) },
              onProfile: { profileCoachId = coach.id }
            )
            if coach.id != visible.last?.id { Divider() }
          }
        }

        if coaches.count > 5 {
          Button {
            isShowingAllCoaches = true
          } label: {
            Text("View all \(coaches.count) coaches")
              .font(.caption)
              .foregroundStyle(Color.accentBlue)
          }
          .frame(minHeight: 44)
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    // Refresh AFTER the sheet fully dismisses (onDismiss), not mid-teardown — a refresh
    // fired before dismissal races the transition and its result is dropped. onSent only
    // flags that a send happened so a pure cancel doesn't trigger a needless reload.
    .sheet(item: $quickCommContext, onDismiss: {
      if didSendFromQuickComm {
        didSendFromQuickComm = false
        onCoachContacted?()
      }
    }) { context in
      QuickCommunicationView(context: context, onSent: { didSendFromQuickComm = true })
    }
    .sheet(item: Binding(
      get: { profileCoachId.map { CoachProfileRoute(id: $0) } },
      set: { profileCoachId = $0?.id }
    )) { route in
      CoachDetailView(coachId: route.id, allCoaches: coaches, allSchools: schools)
    }
    .sheet(isPresented: $isShowingAllCoaches) {
      CoachesListView()
    }
    .sheet(isPresented: $isShowingAddSchool, onDismiss: { onCoachContacted?() }) {
      CoachFollowupAddSchoolSheet(familyUnitId: familyUnitId, userId: userId)
    }
    .sheet(isPresented: $isShowingAddCoach, onDismiss: { onCoachContacted?() }) {
      CoachFollowupAddCoachSheet(familyUnitId: familyUnitId, userId: userId)
    }
  }

  /// Empty state for fresh accounts: no coaches tracked yet, branched on whether any
  /// school is followed. Mirrors web's `CoachFollowupWidget.vue` onboarding CTA.
  private var onboardingCTA: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(schools.isEmpty ? "🏫 Start tracking your recruiting" : "🎯 Add your first coach")
        .font(.subheadline.weight(.semibold))
      Text(schools.isEmpty
           ? "Follow a school to get coach follow-up reminders"
           : "Add a coach to start getting follow-up reminders")
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
      Button {
        if schools.isEmpty {
          isShowingAddSchool = true
        } else {
          isShowingAddCoach = true
        }
      } label: {
        Text(schools.isEmpty ? "Follow a School" : "Add a Coach")
          .font(.caption.weight(.semibold))
      }
      .buttonStyle(.borderedProminent)
      .frame(minHeight: 44)
    }
    .padding(.vertical)
  }

  private func presentQuickComm(_ coach: Coach) {
    quickCommContext = QuickCommunicationContext(
      coach: coach,
      schoolName: EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap)
    )
  }
}

/// Presents the Add School flow for the follow-up widget's empty-state CTA, mirroring
/// `ActionItemAddSchoolSheet` (`ActionItemSheets.swift`).
private struct CoachFollowupAddSchoolSheet: View {
  let familyUnitId: String
  let userId: String

  @State private var navigationPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navigationPath) {
      AddSchoolView(
        schoolsService: SchoolsServiceImpl(supabaseManager: .shared),
        familyUnitId: familyUnitId,
        userId: userId,
        navigationPath: $navigationPath
      )
      .navigationDestination(for: SchoolDestination.self) { destination in
        if case .detail(let schoolId) = destination {
          SchoolDetailView(schoolId: schoolId)
        }
      }
    }
  }
}

/// Presents the Add Coach flow for the follow-up widget's empty-state CTA, mirroring
/// `CoachesListView`'s `.add` navigation destination.
private struct CoachFollowupAddCoachSheet: View {
  let familyUnitId: String
  let userId: String

  @State private var navigationPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navigationPath) {
      AddCoachView(
        coachesService: CoachesServiceImpl(supabaseManager: .shared),
        familyUnitId: familyUnitId,
        userId: userId,
        navigationPath: $navigationPath
      )
    }
  }
}

/// Identifiable wrapper so a coach id can drive `.sheet(item:)`.
private struct CoachProfileRoute: Identifiable {
  let id: String
}

#Preview {
  ScrollView {
    let coaches = [
      Coach(id: "1", firstName: "Pat", lastName: "Rivera", email: "pat@u.edu",
            phone: "5551234567", schoolId: "s1", lastContactDate: nil,
            createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"),
      Coach(id: "2", firstName: "Sam", lastName: "Lee", email: nil, phone: nil,
            schoolId: "s2", lastContactDate: "2026-01-01T00:00:00Z",
            createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
    ]
    CoachFollowupWidget(coaches: coaches, allCoaches: coaches, schools: [])
      .padding()
  }
}

#Preview("Onboarding — no schools") {
  CoachFollowupWidget(coaches: [], allCoaches: [], schools: [])
    .padding()
}

#Preview("Onboarding — no coaches") {
  let school = School(
    id: "s1", userId: "user-1", name: "State U", location: nil, city: nil, state: nil,
    division: nil, conference: nil, ranking: nil, isFavorite: false, website: nil,
    faviconUrl: nil, twitterHandle: nil, instagramHandle: nil, ncaaId: nil,
    status: "interested", statusChangedAt: nil, notes: nil, pros: [], cons: [],
    offerDetails: nil, academicInfo: nil, amenities: nil, coachingPhilosophy: nil,
    coachingStyle: nil, recruitingApproach: nil, communicationStyle: nil,
    successMetrics: nil, familyUnitId: "family-1", createdBy: nil, updatedBy: nil,
    createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"
  )
  CoachFollowupWidget(coaches: [], allCoaches: [], schools: [school])
    .padding()
}
