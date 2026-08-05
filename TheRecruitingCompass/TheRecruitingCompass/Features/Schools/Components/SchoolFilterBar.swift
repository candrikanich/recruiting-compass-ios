import SwiftUI

struct SchoolFilterBar: View {
  @Binding var filters: SchoolFilters
  let availableStates: [String]
  let hasHomeLocation: Bool

  @Environment(\.sizeCategory) private var sizeCategory

  private var chipHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 52 : 44
  }

  var body: some View {
    VStack(spacing: 12) {
      row1
      row2
      row3
      if hasHomeLocation {
        row4
      } else {
        distanceWarning
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .background(Color(.systemGroupedBackground))
  }

  // MARK: - Row 1: Division, Status, State, Favorites

  @ViewBuilder
  private var row1: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        divisionMenu
        statusMenu
        stateMenu
        favoritesToggle
      }
    }
    .scrollIndicators(.hidden)
  }

  @ViewBuilder
  private var divisionMenu: some View {
    Menu {
      Button("All Divisions") {
        filters.division = nil
      }

      ForEach(Division.allCases, id: \.self) { division in
        Button(division.displayName) {
          filters.division = division
        }
      }
    } label: {
      FilterMenuButton(
        label: filters.division?.displayName ?? "Division",
        isActive: filters.division != nil,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "Division filter"))
    .accessibilityValue(filters.division?.displayName ?? "All")
    .accessibilityHint("Double tap to change division filter")
  }

  @ViewBuilder
  private var statusMenu: some View {
    Menu {
      Button("All Statuses") {
        filters.status = nil
      }

      ForEach(SchoolStatus.allCases, id: \.self) { status in
        Button(status.displayName) {
          filters.status = status
        }
      }
    } label: {
      FilterMenuButton(
        label: filters.status?.displayName ?? "Status",
        isActive: filters.status != nil,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "Status filter"))
    .accessibilityValue(filters.status?.displayName ?? "All")
    .accessibilityHint("Double tap to change status filter")
  }

  @ViewBuilder
  private var stateMenu: some View {
    Menu {
      Button("All States") {
        filters.state = nil
      }

      ForEach(availableStates, id: \.self) { state in
        Button(state) {
          filters.state = state
        }
      }
    } label: {
      FilterMenuButton(
        label: filters.state ?? "State",
        isActive: filters.state != nil,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "State filter"))
    .accessibilityValue(filters.state ?? "All")
    .accessibilityHint("Double tap to change state filter")
  }

  @ViewBuilder
  private var favoritesToggle: some View {
    Button(action: { filters.isFavoritesOnly.toggle() }) {
      HStack(spacing: 4) {
        Image(systemName: filters.isFavoritesOnly ? "star.fill" : "star")
          .accessibilityHidden(true)
        Text("Favorites")
      }
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundStyle(filters.isFavoritesOnly ? .white : .primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(minHeight: chipHeight)
      .background(filters.isFavoritesOnly ? Color.blue : Color(.systemGray5))
      .clipShape(Capsule())
    }
    .accessibilityLabel(String(localized: "Favorites filter"))
    .accessibilityValue(filters.isFavoritesOnly ? "Active" : "Inactive")
    .accessibilityHint("Double tap to toggle favorites filter")
    .accessibilityAddTraits(.isButton)
  }

  // MARK: - Row 2: Sort

  @ViewBuilder
  private var row2: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        sortMenu
      }
    }
    .scrollIndicators(.hidden)
  }

  @ViewBuilder
  private var sortMenu: some View {
    Menu {
      ForEach(SchoolSortOption.allCases, id: \.self) { option in
        Button(option.displayName) {
          filters.sortBy = option
        }
      }
    } label: {
      FilterMenuButton(
        label: "Sort: \(filters.sortBy.displayName)",
        isActive: true,
        style: .capsule
      )
    }
    .accessibilityLabel(String(localized: "Sort order"))
    .accessibilityValue(filters.sortBy.displayName)
    .accessibilityHint("Double tap to change sort order")
  }

  // MARK: - Row 3: Fit Score Sliders

  @ViewBuilder
  private var row3: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Fit Score Range")
          .font(.subheadline)
          .fontWeight(.medium)

        Spacer()

        Text("\(Int(filters.fitScoreMin ?? 0)) - \(Int(filters.fitScoreMax ?? 100))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Min")
            .font(.caption)
            .foregroundStyle(.secondary)

          Slider(
            value: Binding(
              get: { filters.fitScoreMin ?? 0 },
              set: { filters.fitScoreMin = $0 }
            ),
            in: 0...100,
            step: 5
          )
          .accessibilityLabel(String(localized: "Minimum fit score"))
          .accessibilityValue("\(Int(filters.fitScoreMin ?? 0))")
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Max")
            .font(.caption)
            .foregroundStyle(.secondary)

          Slider(
            value: Binding(
              get: { filters.fitScoreMax ?? 100 },
              set: { filters.fitScoreMax = $0 }
            ),
            in: 0...100,
            step: 5
          )
          .accessibilityLabel(String(localized: "Maximum fit score"))
          .accessibilityValue("\(Int(filters.fitScoreMax ?? 100))")
        }
      }
    }
    .padding(.horizontal, 4)
  }

  // MARK: - Row 4: Distance Slider

  @ViewBuilder
  private var row4: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Max Distance")
          .font(.subheadline)
          .fontWeight(.medium)

        Spacer()

        if let maxDistance = filters.maxDistance {
          Text("\(Int(maxDistance)) miles")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("No limit")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Slider(
        value: Binding(
          get: { filters.maxDistance ?? 500 },
          set: { filters.maxDistance = $0 }
        ),
        in: 0...500,
        step: 25
      )
      .accessibilityLabel(String(localized: "Maximum distance"))
      .accessibilityValue(filters.maxDistance.map { "\(Int($0)) miles" } ?? "No limit")
    }
    .padding(.horizontal, 4)
  }

  @ViewBuilder
  private var distanceWarning: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(.orange)
        .accessibilityHidden(true)

      Text("Distance filter disabled: Set home location in settings")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 4)
    .accessibilityLabel(String(localized: "Distance filter disabled"))
    .accessibilityHint("Set home location in settings to enable distance filtering")
  }

}

#Preview {
  SchoolFilterBar(
    filters: .constant(SchoolFilters()),
    availableStates: ["CA", "NY", "TX"],
    hasHomeLocation: true
  )
}
