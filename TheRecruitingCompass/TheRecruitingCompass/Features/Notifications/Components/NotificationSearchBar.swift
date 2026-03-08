import SwiftUI

struct NotificationSearchBar: View {
  @Binding var searchText: String
  let onSearchChanged: (String) -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      TextField("Search notifications", text: $searchText)
        .textFieldStyle(.plain)
        .autocorrectionDisabled()
        .accessibilityIdentifier("Search notifications")
        .onChange(of: searchText) { _, newValue in
          onSearchChanged(newValue)
        }

      if !searchText.isEmpty {
        Button {
          searchText = ""
          onSearchChanged("")
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Clear text")
      }
    }
    .padding(10)
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 10))
    .padding(.horizontal)
    .frame(minHeight: 44)
  }
}
