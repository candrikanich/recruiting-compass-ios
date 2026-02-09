import SwiftUI

struct InteractionFilterBar: View {
  @Binding var filters: InteractionFilters
  let showLoggedByFilter: Bool
  let linkedAthletes: [FamilyMember]
  let currentUserId: String?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        // Type filter
        Menu {
          Button("All Types") {
            filters.type = nil
          }

          Divider()

          ForEach(InteractionType.allCases, id: \.self) { type in
            Button {
              filters.type = type
            } label: {
              HStack {
                if filters.type == type {
                  Image(systemName: "checkmark")
                }
                Text(type.displayName)
              }
            }
          }
        } label: {
          FilterMenuButton(
            label: filters.type?.displayName ?? "Type",
            isActive: filters.type != nil,
            style: .rounded
          )
        }

        // Direction filter
        Menu {
          Button("All Directions") {
            filters.direction = nil
          }

          Divider()

          ForEach(Direction.allCases, id: \.self) { direction in
            Button {
              filters.direction = direction
            } label: {
              HStack {
                if filters.direction == direction {
                  Image(systemName: "checkmark")
                }
                Text(direction.displayName)
              }
            }
          }
        } label: {
          FilterMenuButton(
            label: filters.direction?.displayName ?? "Direction",
            isActive: filters.direction != nil,
            style: .rounded
          )
        }

        // Sentiment filter
        Menu {
          Button("All Sentiments") {
            filters.sentiment = nil
          }

          Divider()

          ForEach(Sentiment.allCases, id: \.self) { sentiment in
            Button {
              filters.sentiment = sentiment
            } label: {
              HStack {
                if filters.sentiment == sentiment {
                  Image(systemName: "checkmark")
                }
                Text(sentiment.displayName)
              }
            }
          }
        } label: {
          FilterMenuButton(
            label: filters.sentiment?.displayName ?? "Sentiment",
            isActive: filters.sentiment != nil,
            style: .rounded
          )
        }

        // Time period filter
        Menu {
          Button("All Time") {
            filters.timePeriod = nil
          }

          Divider()

          ForEach(TimePeriod.allCases, id: \.self) { period in
            Button {
              filters.timePeriod = period
            } label: {
              HStack {
                if filters.timePeriod == period {
                  Image(systemName: "checkmark")
                }
                Text(period.displayName)
              }
            }
          }
        } label: {
          FilterMenuButton(
            label: filters.timePeriod?.displayName ?? "Time Period",
            isActive: filters.timePeriod != nil,
            style: .rounded
          )
        }

        // Logged By filter (parents only)
        if showLoggedByFilter {
          Menu {
            Button("All Family Members") {
              filters.loggedBy = nil
            }

            Divider()

            // "Me" option
            if let currentUserId {
              Button {
                filters.loggedBy = currentUserId
              } label: {
                HStack {
                  if filters.loggedBy == currentUserId {
                    Image(systemName: "checkmark")
                  }
                  Text("Me")
                }
              }
            }

            // Athlete options
            ForEach(linkedAthletes, id: \.id) { athlete in
              Button {
                filters.loggedBy = athlete.userId
              } label: {
                HStack {
                  if filters.loggedBy == athlete.userId {
                    Image(systemName: "checkmark")
                  }
                  Text(athlete.fullName)
                }
              }
            }
          } label: {
            FilterMenuButton(
              label: loggedByTitle,
              isActive: filters.loggedBy != nil,
              style: .rounded
            )
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }

  // MARK: - Computed Properties

  private var loggedByTitle: String {
    guard let loggedBy = filters.loggedBy else {
      return "Logged By"
    }

    if loggedBy == currentUserId {
      return "Me"
    }

    if let athlete = linkedAthletes.first(where: { $0.userId == loggedBy }) {
      return athlete.fullName
    }

    return "Logged By"
  }
}

#Preview {
  @Previewable @State var filters = InteractionFilters()

  InteractionFilterBar(
    filters: $filters,
    showLoggedByFilter: true,
    linkedAthletes: [],
    currentUserId: "user1"
  )
  .padding()
  .background(Color(.systemGroupedBackground))
}
