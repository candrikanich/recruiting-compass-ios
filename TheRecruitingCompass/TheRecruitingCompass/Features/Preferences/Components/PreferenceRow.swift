import SwiftUI

struct PreferenceRow: View {
  let preference: SchoolPreference
  let onToggleDealbreaker: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: categoryIcon)
        .foregroundStyle(categoryColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(preferenceLabel)
          .font(.subheadline)
          .fontWeight(.medium)

        Text(valueDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if preference.isDealbreaker {
        Text("DEALBREAKER")
          .font(.caption)
          .bold()
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.red)
          .clipShape(.rect(cornerRadius: 4))
      }

      Button {
        onToggleDealbreaker()
      } label: {
        Image(systemName: preference.isDealbreaker ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
          .foregroundStyle(preference.isDealbreaker ? .red : .gray)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(preference.isDealbreaker ? "Remove dealbreaker" : "Mark as dealbreaker")
    }
    .accessibilityElement(children: .contain)
  }

  private var categoryIcon: String {
    switch preference.category {
    case .location: return "mappin.circle.fill"
    case .academic: return "book.fill"
    case .program: return "sportscourt.fill"
    case .custom: return "star.fill"
    }
  }

  private var categoryColor: Color {
    switch preference.category {
    case .location: return .blue
    case .academic: return .green
    case .program: return .orange
    case .custom: return .purple
    }
  }

  private var preferenceLabel: String {
    switch preference.type {
    case "max_distance_miles": return "Max Distance"
    case "preferred_regions": return "Preferred Regions"
    case "preferred_states": return "Preferred States"
    case "min_academic_rating": return "Min Academic Rating"
    case "school_size": return "School Size"
    case "division": return "Division"
    case "conference_type": return "Conference Type"
    case "scholarship_required": return "Scholarship Required"
    case "must_have": return "Must Have"
    case "nice_to_have": return "Nice to Have"
    default: return preference.type
    }
  }

  private var valueDescription: String {
    switch preference.value {
    case .string(let str):
      return str
    case .int(let num):
      if preference.type == "max_distance_miles" {
        return "\(num) miles"
      }
      return "\(num)"
    case .bool(let bool):
      return bool ? "Yes" : "No"
    case .stringArray(let arr):
      return arr.joined(separator: ", ")
    }
  }
}
