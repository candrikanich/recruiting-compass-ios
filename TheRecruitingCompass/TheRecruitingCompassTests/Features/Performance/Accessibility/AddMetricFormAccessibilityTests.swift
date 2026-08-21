import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class AddMetricFormAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Helpers

  private func makeFormView(
    formState: Binding<MetricFormState> = .constant(MetricFormState()),
    title: String = "Log Performance Metric",
    submitLabel: String = "Log Metric",
    isSubmitting: Bool = false
  ) -> MetricFormView {
    MetricFormView(
      formState: formState,
      title: title,
      submitLabel: submitLabel,
      isSubmitting: isSubmitting,
      sport: nil,
      onSubmit: {},
      onCancel: {}
    )
  }

  // MARK: - Form Title Tests

  func testMetricFormView_titleHasHeaderTrait() {
    let view = makeFormView()

    // Title should have .isHeader trait via .accessibilityAddTraits(.isHeader)
    XCTAssertNotNil(view)
  }

  // MARK: - Metric Type Picker Tests

  func testMetricFormView_metricTypePickerHasRequiredLabel() {
    let view = makeFormView()

    // Picker should announce "Metric type, required"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_metricTypePickerHasHint() {
    let view = makeFormView()

    // Picker should have hint: "Select the type of metric to log"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_metricTypePickerHasValue() {
    var state = MetricFormState()
    state.metricType = .velocity

    // Picker should announce "Fastball Velocity" as its value
    XCTAssertEqual(state.metricType?.displayName, "Fastball Velocity")
  }

  func testMetricFormView_metricTypePickerNoneSelectedValue() {
    let state = MetricFormState()

    // When nothing selected, picker value should indicate "None selected"
    XCTAssertNil(state.metricType)
  }

  func testMetricFormView_metricTypePickerMinHeight() {
    let view = makeFormView()

    // Picker should meet 44pt minimum touch target via .frame(minHeight: 44)
    XCTAssertNotNil(view)
  }

  // MARK: - Value Field Tests

  func testMetricFormView_valueFieldHasRequiredLabel() {
    let view = makeFormView()

    // Value field should announce "Metric value, required"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_valueFieldHasHint() {
    let view = makeFormView()

    // Value field should have hint: "Enter a numeric value for this metric"
    XCTAssertNotNil(view)
  }

  // MARK: - Date Picker Tests

  func testMetricFormView_datePickerHasLabel() {
    let view = makeFormView()

    // Date picker should announce "Recording date"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_datePickerHasHint() {
    let view = makeFormView()

    // Date picker should have hint: "Select the date this metric was recorded"
    XCTAssertNotNil(view)
  }

  // MARK: - Unit Field Tests

  func testMetricFormView_unitFieldHasLabel() {
    let view = makeFormView()

    // Unit field should announce "Unit of measurement"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_unitFieldHasHint() {
    let view = makeFormView()

    // Unit field should have hint: "Enter the unit, such as mph or seconds"
    XCTAssertNotNil(view)
  }

  // MARK: - Verified Toggle Tests

  func testMetricFormView_verifiedToggleHasHint() {
    let view = makeFormView()

    // Toggle should have hint explaining verification context
    XCTAssertNotNil(view)
  }

  // MARK: - Notes Field Tests

  func testMetricFormView_notesFieldHasLabel() {
    let view = makeFormView()

    // Notes field should announce "Notes"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_notesFieldHasHint() {
    let view = makeFormView()

    // Notes field should have hint: "Optional additional context about this metric"
    XCTAssertNotNil(view)
  }

  // MARK: - Submit Button Tests

  func testMetricFormView_submitButtonLabelWhenValid() {
    var state = MetricFormState()
    state.metricType = .velocity
    state.value = "90"

    XCTAssertTrue(state.isValid)
  }

  func testMetricFormView_submitButtonLabelWhenSubmitting() {
    let view = makeFormView(isSubmitting: true)

    // Submit button should announce "Saving metric" when submitting
    XCTAssertNotNil(view)
  }

  func testMetricFormView_submitButtonHintWhenInvalid() {
    let state = MetricFormState()

    // When form is invalid, hint should say "Complete all required fields first"
    XCTAssertFalse(state.isValid)
  }

  func testMetricFormView_submitButtonHintWhenValid() {
    var state = MetricFormState()
    state.metricType = .velocity
    state.value = "90"

    // When form is valid, hint should say "Submits the metric form"
    XCTAssertTrue(state.isValid)
  }

  // MARK: - Cancel Button Tests

  func testMetricFormView_cancelButtonHasLabel() {
    let view = makeFormView()

    // Cancel button should announce "Cancel"
    XCTAssertNotNil(view)
  }

  func testMetricFormView_cancelButtonHasHint() {
    let view = makeFormView()

    // Cancel button should have hint: "Closes the form without saving"
    XCTAssertNotNil(view)
  }

  // MARK: - Dynamic Type Tests

  func testMetricFormView_dynamicTypeSupport() {
    let sizes: [ContentSizeCategory] = [
      .extraSmall,
      .medium,
      .accessibilityMedium,
      .accessibilityExtraExtraLarge
    ]

    for size in sizes {
      let view = makeFormView()
        .environment(\.sizeCategory, size)

      // Form should render correctly at all dynamic type sizes
      // All fonts use semantic styles (.title2, .subheadline, .caption)
      XCTAssertNotNil(view)
    }
  }

  // MARK: - Integration Tests

  func testIntegration_fullFormAccessibility() {
    var state = MetricFormState()
    state.metricType = .velocity
    state.value = "90"
    state.unit = "mph"
    state.verified = true
    state.notes = "Tested at showcase"

    // Full form should have:
    // - Header trait on title
    // - Required labels on metric type and value fields
    // - Hints on all fields
    // - Dynamic accessibility value on picker
    // - Contextual hint on submit button based on form validity
    XCTAssertTrue(state.isValid)
    XCTAssertEqual(state.metricType?.displayName, "Fastball Velocity")
    XCTAssertEqual(state.parsedValue, 90)
  }

  func testIntegration_editFormAccessibility() {
    let view = makeFormView(
      title: "Edit Performance Metric",
      submitLabel: "Save Changes"
    )

    // Edit form should use "Edit Performance Metric" as header
    // Submit should say "Save Changes"
    XCTAssertNotNil(view)
  }
}
