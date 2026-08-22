import SwiftUI

struct EventMetricForm: View {
  private enum Layout {
    static let contentSpacing: CGFloat = 12
    static let unitFieldWidth: CGFloat = 80
    static let cornerRadius: CGFloat = 12
  }

  @Binding var data: NewMetricData
  /// The athlete's `primary_sport` — filters the Metric Type picker to that
  /// sport's metrics (falls back to the default baseball order when nil).
  let sport: String?
  let isSaving: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: Layout.contentSpacing) {
      Picker("Metric Type", selection: $data.metricType) {
        ForEach(MetricRegistry.types(forSport: sport).map(MetricType.init(rawValue:))) { type in
          Text(type.displayName).tag(type)
        }
      }
      .accessibilityLabel(String(localized: "Metric type"))
      .accessibilityHint("Select the type of metric to record")

      HStack(spacing: Layout.contentSpacing) {
        TextField("Value", text: $data.valueText)
          .keyboardType(.decimalPad)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel(String(localized: "Metric value"))
          .accessibilityHint("Enter a numeric value")

        TextField("Unit", text: $data.unit)
          .textFieldStyle(.roundedBorder)
          .frame(width: Layout.unitFieldWidth)
          .accessibilityLabel(String(localized: "Unit of measurement"))
          .accessibilityHint("Enter the unit, such as mph or seconds")
      }

      TextField("Notes (optional)", text: $data.notes, axis: .vertical)
        .lineLimit(2...4)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(String(localized: "Metric notes"))

      HStack(spacing: Layout.contentSpacing) {
        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)
          .frame(minHeight: 44)
          .accessibilityLabel(String(localized: "Cancel adding metric"))

        Button(action: onSave) {
          if isSaving {
            ProgressView()
          } else {
            Text("Save Metric")
          }
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .disabled(!data.isValid || isSaving)
        .accessibilityLabel(isSaving ? String(localized: "Saving metric") : String(localized: "Save metric"))
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    .onChange(of: data.metricType) { _, newValue in
      if data.unit.isEmpty {
        data.unit = newValue.defaultUnit
      }
    }
    .onAppear(perform: applySportDefault)
  }

  /// Snap the selection to the sport's first metric when the current default
  /// isn't part of this sport's list (e.g. baseball's `velocity` under a
  /// basketball athlete), so the picker never opens on an out-of-sport metric.
  private func applySportDefault() {
    let sportMetrics = MetricRegistry.types(forSport: sport)
    guard !sportMetrics.contains(data.metricType.rawValue),
          let first = sportMetrics.first else { return }
    data.metricType = MetricType(rawValue: first)
  }
}
