import SwiftUI

struct CoachFilterBar: View {
  @Binding var filters: CoachFilters

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        roleMenu
        lastContactMenu
        responsivenessMenu
        sortMenu
      }
      .padding(.horizontal, 16)
    }
  }

  // MARK: - Role Filter

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
      filterChip(
        label: filters.role?.displayName ?? "Role",
        isActive: filters.role != nil
      )
    }
    .accessibilityLabel("Filter by role")
    .accessibilityHint("Opens role filter options")
    .accessibilityValue(filters.role?.displayName ?? "All roles")
  }

  // MARK: - Last Contact Filter

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
      filterChip(
        label: lastContactLabel,
        isActive: filters.lastContactDays != nil
      )
    }
    .accessibilityLabel("Filter by last contact")
    .accessibilityHint("Opens time period filter options")
    .accessibilityValue(lastContactLabel)
  }

  private var lastContactLabel: String {
    guard let days = filters.lastContactDays else { return "Last Contact" }
    return LastContactOption(rawValue: days)?.displayName ?? "Last \(days) days"
  }

  // MARK: - Responsiveness Filter

  private var responsivenessMenu: some View {
    Menu {
      Button("All levels") {
        filters.responsivenessLevel = nil
      }

      ForEach(ResponsivenessLevel.allCases, id: \.self) { level in
        Button(level.displayName) {
          filters.responsivenessLevel = level
        }
      }
    } label: {
      filterChip(
        label: filters.responsivenessLevel?.displayName ?? "Responsiveness",
        isActive: filters.responsivenessLevel != nil
      )
    }
    .accessibilityLabel("Filter by responsiveness")
    .accessibilityHint("Opens responsiveness level filter options")
    .accessibilityValue(filters.responsivenessLevel?.displayName ?? "All levels")
  }

  // MARK: - Sort Menu

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
      filterChip(
        label: "Sort: \(filters.sortBy.displayName)",
        isActive: false
      )
    }
    .accessibilityLabel("Sort coaches")
    .accessibilityHint("Opens sort options")
    .accessibilityValue("Sorted by \(filters.sortBy.displayName)")
  }

  // MARK: - Chip

  private func filterChip(label: String, isActive: Bool) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.subheadline)

      Image(systemName: "chevron.down")
        .font(.caption2)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(minHeight: 44)
    .background(isActive ? Color.accentBlue.opacity(0.12) : Color(.secondarySystemBackground))
    .foregroundStyle(isActive ? Color.accentBlue : Color.primary)
    .clipShape(Capsule())
  }
}

#Preview {
  CoachFilterBar(filters: .constant(CoachFilters()))
}
