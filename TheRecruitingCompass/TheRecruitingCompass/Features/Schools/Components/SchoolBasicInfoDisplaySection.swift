import SwiftUI
import Foundation

/// Section displaying school contact & social information with edit capability
struct SchoolBasicInfoDisplaySection: View {
  let school: School
  let onEdit: () -> Void

  private func isPresent(_ value: String?) -> Bool {
    guard let value else { return false }
    return !value.isEmpty
  }

  private var hasContactInfo: Bool {
    isPresent(school.academicInfo?.address)
      || isPresent(school.phone)
      || isPresent(school.website)
      || isPresent(school.twitterHandle)
      || isPresent(school.instagramHandle)
  }

  @ViewBuilder
  private func socialRow(label: String, handle: String?, baseURL: String) -> some View {
    if let handle, !handle.isEmpty {
      let stripped = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
      HStack(alignment: .top) {
        Text("\(label):")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        if let url = URL(string: "\(baseURL)\(stripped)") {
          Link(destination: url) {
            HStack(spacing: 4) {
              Text(handle)
                .font(.subheadline)
              Image(systemName: "safari")
                .font(.subheadline)
            }
          }
        } else {
          Text(handle)
            .font(.subheadline)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(String(localized: "\(label): \(handle). Tap to open."))
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Contact & Social")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button("Edit") {
          onEdit()
        }
        .accessibilityLabel(String(localized: "Edit contact and social"))
      }

      if let address = school.academicInfo?.address, !address.isEmpty {
        InfoRow(label: "Campus Address", value: address)
      }

      if let phone = school.phone, !phone.isEmpty {
        HStack(alignment: .top) {
          Text("Phone:")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          if let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
            Link(phone, destination: url)
              .font(.subheadline)
          } else {
            Text(phone)
              .font(.subheadline)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Phone: \(phone). Tap to call."))
      }

      socialRow(label: "Twitter", handle: school.twitterHandle, baseURL: "https://twitter.com/")
      socialRow(label: "Instagram", handle: school.instagramHandle, baseURL: "https://instagram.com/")

      if !hasContactInfo {
        Text("No contact info yet. Tap Edit to add a website, socials, or phone.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
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
