import SwiftUI
import Foundation

/// Section displaying school basic information with edit capability
struct SchoolBasicInfoDisplaySection: View {
  let school: School
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Information")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button("Edit") {
          onEdit()
        }
        .accessibilityLabel(String(localized: "Edit school information"))
      }

      if let info = school.academicInfo {
        VStack(alignment: .leading, spacing: 8) {
          if let address = info.address {
            InfoRow(label: "Campus Address", value: address)
          }

          if let facility = info.baseballFacilityAddress {
            InfoRow(label: "Baseball Facility", value: facility)
          }

          if let mascot = info.mascot {
            InfoRow(label: "Mascot", value: mascot)
          }

          if let size = info.undergradSize {
            InfoRow(label: "Undergrad Size", value: size)
          }
        }
      }

      if let website = school.website, !website.isEmpty {
        let urlString = (website.hasPrefix("http://") || website.hasPrefix("https://"))
          ? website
          : "https://\(website)"
        HStack(alignment: .top) {
          Text("Website:")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          if let url = URL(string: urlString) {
            Link(destination: url) {
              HStack(spacing: 4) {
                Text(website)
                  .font(.subheadline)
                  .multilineTextAlignment(.trailing)
                  .lineLimit(2)
                  .truncationMode(.middle)
                Image(systemName: "safari")
                  .font(.subheadline)
              }
            }
          } else {
            Text(website)
              .font(.subheadline)
              .multilineTextAlignment(.trailing)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Website: \(website). Tap to open in browser."))
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
    .padding(.horizontal)
  }
}

#Preview {
  // Preview removed - requires School model with memberwise initializer
  // Use in-app preview or add mock data factory
  VStack {
    Text("SchoolBasicInfoDisplaySection Preview")
      .font(.caption)
      .foregroundStyle(.secondary)
    Text("Add mock School factory for preview")
      .font(.caption)
      .foregroundStyle(.secondary)
  }
  .padding()
}
