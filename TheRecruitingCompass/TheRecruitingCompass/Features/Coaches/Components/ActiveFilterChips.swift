import SwiftUI

struct ActiveFilterChips: View {
  @Binding var filters: CoachFilters

  var body: some View {
    FilterChipContainer(
      hasFilters: filters.hasActiveFilters,
      style: .outlined,
      onClearAll: clearAllFilters
    ) {
      if let role = filters.role {
        FilterChip(label: role.displayName, style: .outlined) {
          filters.role = nil
        }
      }

      if let days = filters.lastContactDays {
        let label = LastContactOption(rawValue: days)?.displayName ?? "Last \(days) days"
        FilterChip(label: label, style: .outlined) {
          filters.lastContactDays = nil
        }
      }

      if let level = filters.responsivenessLevel {
        FilterChip(label: level.displayName, style: .outlined) {
          filters.responsivenessLevel = nil
        }
      }
    }
  }

  private func clearAllFilters() {
    filters.role = nil
    filters.lastContactDays = nil
    filters.responsivenessLevel = nil
  }
}

#Preview {
  ActiveFilterChips(filters: .constant(CoachFilters(role: .head, lastContactDays: 30)))
}
