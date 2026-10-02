import SwiftUI

/// Splits dashboard content into a 4+2 main/sidebar column layout on iPad (`.regular` width),
/// falling back to a single stacked column on iPhone (`.compact` width). On a foldable's inner
/// display the split moves onto the hinge so no widget straddles the fold.
struct AdaptiveDashboardGrid<MainContent: View, SidebarContent: View>: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var foldSplit: FoldSplit?
  @ViewBuilder let mainContent: () -> MainContent
  @ViewBuilder let sidebarContent: () -> SidebarContent

  var body: some View {
  if sizeClass == .regular {
    regularLayout
  } else {
    compactLayout
  }
  }

  @ViewBuilder
  private var regularLayout: some View {
  HStack(alignment: .top, spacing: foldSplit?.gap ?? 20) {
    mainContent()
    .frame(width: foldSplit?.leadingWidth)
    .frame(maxWidth: .infinity)

    sidebarContent()
    .frame(width: foldSplit?.trailingWidth ?? 300)
  }
  .onGeometryChange(for: FoldSplit?.self) { $0.verticalFoldSplit } action: { foldSplit = $0 }
  }

  @ViewBuilder
  private var compactLayout: some View {
  VStack(spacing: 24) {
    mainContent()
    sidebarContent()
  }
  }
}
