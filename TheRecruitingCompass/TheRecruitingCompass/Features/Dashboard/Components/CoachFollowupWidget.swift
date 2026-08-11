import SwiftUI

struct CoachFollowupWidget: View {
  let coaches: [Coach]
  let schools: [School]

  @State private var isShowingAll = false
  @State private var quickCommContext: QuickCommunicationContext?
  @State private var profileCoachId: String?
  @State private var isShowingAllCoaches = false

  private var schoolNameMap: [String: String] { EntityNameLookup.schoolNameMap(from: schools) }
  private var visibleCoaches: [Coach] { isShowingAll ? coaches : Array(coaches.prefix(5)) }

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

      if coaches.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          Text("🎉 All caught up!")
            .font(.subheadline.weight(.semibold))
          Text("No coaches need immediate follow-up")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical)
      } else {
        VStack(spacing: 8) {
          ForEach(visibleCoaches) { coach in
            CoachFollowupRow(
              coach: coach,
              schoolName: EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap),
              onEmail: { presentQuickComm(coach) },
              onText: { presentQuickComm(coach) },
              onProfile: { profileCoachId = coach.id }
            )
            if coach.id != visibleCoaches.last?.id { Divider() }
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
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .sheet(item: $quickCommContext) { context in
      QuickCommunicationView(context: context)
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
  }

  private func presentQuickComm(_ coach: Coach) {
    quickCommContext = QuickCommunicationContext(
      coach: coach,
      schoolName: EntityNameLookup.schoolName(for: coach.schoolId, in: schoolNameMap)
    )
  }
}

/// Identifiable wrapper so a coach id can drive `.sheet(item:)`.
private struct CoachProfileRoute: Identifiable {
  let id: String
}

#Preview {
  ScrollView {
    CoachFollowupWidget(
      coaches: [
        Coach(id: "1", firstName: "Pat", lastName: "Rivera", email: "pat@u.edu",
              phone: "5551234567", schoolId: "s1", lastContactDate: nil,
              createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z"),
        Coach(id: "2", firstName: "Sam", lastName: "Lee", email: nil, phone: nil,
              schoolId: "s2", lastContactDate: "2026-01-01T00:00:00Z",
              createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
      ],
      schools: []
    )
    .padding()
  }
}
