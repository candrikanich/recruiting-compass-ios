import SwiftUI

struct ActiveFilterChips: View {
  @Binding var filters: CoachFilters

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        if let role = filters.role {
          chip(label: role.displayName) {
            filters.role = nil
          }
        }

        if let days = filters.lastContactDays {
          let label = LastContactOption(rawValue: days)?.displayName ?? "Last \(days) days"
          chip(label: label) {
            filters.lastContactDays = nil
          }
        }

        if let level = filters.responsivenessLevel {
          chip(label: level.displayName) {
            filters.responsivenessLevel = nil
          }
        }

        if filters.hasActiveFilters {
          Button("Clear all") {
            filters.role = nil
            filters.lastContactDays = nil
            filters.responsivenessLevel = nil
          }
          .font(.subheadline)
          .foregroundStyle(Color.accentBlue)
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
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.accentBlue.opacity(0.12))
    .foregroundStyle(Color.accentBlue)
    .clipShape(Capsule())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label) filter active")
    .accessibilityHint("Double tap to remove this filter")
    .accessibilityAddTraits(.isButton)
  }
}

#Preview {
  ActiveFilterChips(filters: .constant(CoachFilters(role: .head, lastContactDays: 30)))
}
