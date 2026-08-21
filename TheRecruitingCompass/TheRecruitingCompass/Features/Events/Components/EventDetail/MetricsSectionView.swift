import SwiftUI

struct MetricsSectionView: View {
  private enum Layout {
    static let rowInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
  }

  let metrics: [PerformanceMetric]
  let showMetricForm: Bool
  @Binding var newMetricData: NewMetricData
  /// The athlete's `primary_sport`, forwarded to `EventMetricForm`'s picker.
  /// `EventDetailViewModel` doesn't load `PlayerDetails` today, so callers
  /// pass nil (falls back to the default baseball order in `MetricRegistry`).
  let sport: String?
  let isSavingMetric: Bool
  let onDeleteMetric: (String) async -> Void
  let onSaveMetric: () async -> Void
  let onStartAdd: () -> Void
  let onCancelAdd: () -> Void
  var onExport: (() -> Void)?

  var body: some View {
    Section {
      ForEach(metrics) { metric in
        MetricCardView(metric: metric)
          .listRowInsets(Layout.rowInsets)
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
              Task { await onDeleteMetric(metric.id) }
            } label: {
              Label("Delete \(metric.displayName) metric", systemImage: "trash")
            }
          }
      }

      if showMetricForm {
        EventMetricForm(
          data: $newMetricData,
          sport: sport,
          isSaving: isSavingMetric,
          onSave: { Task { await onSaveMetric() } },
          onCancel: onCancelAdd
        )
        .listRowInsets(Layout.rowInsets)
      }

      if !showMetricForm {
        Button {
          onStartAdd()
        } label: {
          Label("Add Metric", systemImage: "plus.circle")
        }
        .accessibilityLabel(String(localized: "Add a new performance metric"))
      }
    } header: {
      HStack {
        Text("Metrics Recorded at This Event")
        Spacer()
        if !metrics.isEmpty, let onExport {
          Button {
            onExport()
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
          .buttonStyle(.plain)
          .accessibilityLabel(String(localized: "Export metrics"))
          .accessibilityHint("Exports metrics as CSV file")
        }
        Text("\(metrics.count)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}
