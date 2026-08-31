import SwiftUI

/// Splits dashboard content into a 4+2 main/sidebar column layout on iPad (`.regular` width),
/// falling back to a single stacked column on iPhone (`.compact` width).
struct AdaptiveDashboardGrid<MainContent: View, SidebarContent: View>: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
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
  HStack(alignment: .top, spacing: 20) {
    mainContent()
    .frame(maxWidth: .infinity)

    sidebarContent()
    .frame(width: 300)
  }
  }

  @ViewBuilder
  private var compactLayout: some View {
  VStack(spacing: 24) {
    mainContent()
    sidebarContent()
  }
  }
}
