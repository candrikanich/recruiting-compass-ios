import SwiftUI

struct InteractionActiveFilterChips: View {
  @Binding var filters: InteractionFilters
  let linkedAthletes: [FamilyMember]
  let currentUserId: String?

  var body: some View {
    FilterChipContainer(
      hasFilters: filters.hasActiveFilters,
      style: .outlined,
      onClearAll: clearAllFilters
    ) {
      if let type = filters.type {
        FilterChip(label: type.displayName, style: .outlined) {
          filters.type = nil
        }
      }

      if let direction = filters.direction {
        FilterChip(label: direction.displayName, style: .outlined) {
          filters.direction = nil
        }
      }

      if let sentiment = filters.sentiment {
        FilterChip(label: sentiment.displayName, style: .outlined) {
          filters.sentiment = nil
        }
      }

      if let timePeriod = filters.timePeriod {
        FilterChip(label: timePeriod.displayName, style: .outlined) {
          filters.timePeriod = nil
        }
      }

      if let loggedBy = filters.loggedBy {
        FilterChip(label: loggedByLabel(loggedBy), style: .outlined) {
          filters.loggedBy = nil
        }
      }
    }
  }

  private func clearAllFilters() {
    filters.type = nil
    filters.direction = nil
    filters.sentiment = nil
    filters.timePeriod = nil
    filters.loggedBy = nil
  }

  private func loggedByLabel(_ userId: String) -> String {
    if userId == currentUserId {
      return "Me"
    }

    if let athlete = linkedAthletes.first(where: { $0.userId == userId }) {
      return athlete.fullName
    }

    return "Unknown"
  }
}

#Preview {
  @Previewable @State var filters = InteractionFilters(
    type: .email,
    direction: .outbound,
    timePeriod: .last7Days
  )

  InteractionActiveFilterChips(
    filters: $filters,
    linkedAthletes: [],
    currentUserId: "user1"
  )
}
