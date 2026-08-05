import SwiftUI

struct CoachFilterBar: View {
  @Binding var filters: CoachFilters

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        roleMenu
        lastContactMenu
        sortMenu
      }
      .padding(.horizontal, 16)
    }
    .scrollIndicators(.hidden)
  }

  // MARK: - Role Filter

  @ViewBuilder
  private var roleMenu: some View {
    Menu {
      Button("All Roles") {
        filters.role = nil
      }

      ForEach(CoachRole.allCases, id: \.self) { role in
        Button(role.displayName) {
          filters.role = role
        }
      }
    } label: {
      FilterMenuButton(
        label: filters.role?.displayName ?? "Role",
        isActive: filters.role != nil,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "Filter by role"))
    .accessibilityHint("Opens role filter options")
    .accessibilityValue(filters.role?.displayName ?? "All roles")
  }

  // MARK: - Last Contact Filter

  @ViewBuilder
  private var lastContactMenu: some View {
    Menu {
      Button("Any time") {
        filters.lastContactDays = nil
      }

      ForEach(LastContactOption.allCases, id: \.self) { option in
        Button(option.displayName) {
          filters.lastContactDays = option.rawValue
        }
      }
    } label: {
      FilterMenuButton(
        label: lastContactLabel,
        isActive: filters.lastContactDays != nil,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "Filter by last contact"))
    .accessibilityHint("Opens time period filter options")
    .accessibilityValue(lastContactLabel)
  }

  private var lastContactLabel: String {
    guard let days = filters.lastContactDays else { return "Last Contact" }
    return LastContactOption(rawValue: days)?.displayName ?? "Last \(days) days"
  }

  // MARK: - Sort Menu

  @ViewBuilder
  private var sortMenu: some View {
    Menu {
      ForEach(CoachSortOption.allCases, id: \.self) { option in
        Button {
          filters.sortBy = option
        } label: {
          HStack {
            Text(option.displayName)
            if filters.sortBy == option {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      FilterMenuButton(
        label: "Sort: \(filters.sortBy.displayName)",
        isActive: false,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "Sort coaches"))
    .accessibilityHint("Opens sort options")
    .accessibilityValue("Sorted by \(filters.sortBy.displayName)")
  }

}

#Preview {
  CoachFilterBar(filters: .constant(CoachFilters()))
}
