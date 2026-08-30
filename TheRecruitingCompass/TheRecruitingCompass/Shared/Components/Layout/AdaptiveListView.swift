import SwiftUI

struct AdaptiveListView<Item: Identifiable, CardContent: View>: View {
  let items: [Item]
  @ViewBuilder let cardContent: (Item) -> CardContent
  @Environment(\.horizontalSizeClass) private var sizeClass

  private var gridColumns: [GridItem] {
    [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 16)]
  }

  var body: some View {
    if sizeClass == .regular {
      LazyVGrid(columns: gridColumns, spacing: 16) {
        ForEach(items) { item in
          cardContent(item)
        }
      }
    } else {
      LazyVStack(spacing: 12) {
        ForEach(items) { item in
          cardContent(item)
        }
      }
    }
  }
}
