import SwiftUI

struct InteractionActiveFilterChips: View {
  @Binding var filters: InteractionFilters
  let linkedAthletes: [FamilyMember]
  let currentUserId: String?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        if let type = filters.type {
          chip(label: type.displayName) {
            filters.type = nil
          }
        }

        if let direction = filters.direction {
          chip(label: direction.displayName) {
            filters.direction = nil
          }
        }

        if let sentiment = filters.sentiment {
          chip(label: sentiment.displayName) {
            filters.sentiment = nil
          }
        }

        if let timePeriod = filters.timePeriod {
          chip(label: timePeriod.displayName) {
            filters.timePeriod = nil
          }
        }

        if let loggedBy = filters.loggedBy {
          chip(label: loggedByLabel(loggedBy)) {
            filters.loggedBy = nil
          }
        }

        if filters.hasActiveFilters {
          Button("Clear all") {
            filters.type = nil
            filters.direction = nil
            filters.sentiment = nil
            filters.timePeriod = nil
            filters.loggedBy = nil
          }
          .font(.subheadline)
          .foregroundStyle(Color.blue)
          .accessibilityLabel("Clear all filters")
          .accessibilityHint("Removes all active filters")
        }
      }
      .padding(.horizontal, 16)
    }
  }

  private func chip(label: String, onRemove: @escaping () -> Void) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.subheadline)

      Button {
        onRemove()
      } label: {
        Image(systemName: "xmark")
          .font(.caption2)
          .fontWeight(.bold)
          .frame(minWidth: 24, minHeight: 24)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Remove \(label) filter")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.blue.opacity(0.12))
    .foregroundStyle(Color.blue)
    .clipShape(Capsule())
    .accessibilityElement(children: .contain)
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
