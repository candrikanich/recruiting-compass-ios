import Accessibility

extension AXChartDescriptor {
  /// SwiftUI reuses the first descriptor and calls `updateChartDescriptor` on data changes;
  /// copying every field from a freshly built one keeps creation and update from diverging.
  func replaceContents(with fresh: AXChartDescriptor) {
    title = fresh.title
    summary = fresh.summary
    xAxis = fresh.xAxis
    yAxis = fresh.yAxis
    additionalAxes = fresh.additionalAxes
    series = fresh.series
  }
}
