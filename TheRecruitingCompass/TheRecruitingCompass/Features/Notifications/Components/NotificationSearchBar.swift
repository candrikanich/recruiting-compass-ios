import SwiftUI

struct NotificationSearchBar: View {
  @Binding var searchText: String
  let onSearchChanged: (String) -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)
        .accessibilityHidden(true)

      TextField("Search notifications", text: $searchText)
        .textFieldStyle(.plain)
        .autocorrectionDisabled()
        .onChange(of: searchText) { _, newValue in
          onSearchChanged(newValue)
        }

      if !searchText.isEmpty {
        Button {
          searchText = ""
          onSearchChanged("")
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
        }
        .accessibilityLabel("Clear text")
      }
    }
    .padding(10)
    .background(Color(.systemGray6))
    .cornerRadius(10)
    .padding(.horizontal)
    .frame(minHeight: 44)
  }
}
