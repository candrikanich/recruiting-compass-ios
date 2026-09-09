import SwiftUI

/// Add/edit deadline form. School association is still deferred (spec §9);
/// editing matches web's `PATCH /api/deadlines/:id`.
struct AddDeadlineSheet: View {
  let existingDeadline: Deadline?
  let onSave: (String, Date, DeadlineCategory) async -> Bool
  let onCancel: () -> Void

  @State private var label: String
  @State private var date: Date
  @State private var category: DeadlineCategory
  @State private var isSaving = false

  private static let maxLabelLength = 200

  init(
    existingDeadline: Deadline? = nil,
    onSave: @escaping (String, Date, DeadlineCategory) async -> Bool,
    onCancel: @escaping () -> Void
  ) {
    self.existingDeadline = existingDeadline
    self.onSave = onSave
    self.onCancel = onCancel
    _label = State(initialValue: existingDeadline?.label ?? "")
    _date = State(initialValue: existingDeadline.flatMap { AddDeadlineSheet.parseISODate($0.deadlineDate) } ?? .now)
    _category = State(initialValue: existingDeadline?.category ?? .application)
  }

  private static func parseISODate(_ isoDate: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.date(from: isoDate)
  }

  private var trimmedLabel: String {
    label.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isSaveDisabled: Bool {
    isSaving || trimmedLabel.isEmpty || trimmedLabel.count > Self.maxLabelLength
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Label", text: $label)
            .accessibilityLabel(String(localized: "Deadline label"))
          DatePicker("Date", selection: $date, displayedComponents: .date)
            .accessibilityLabel(String(localized: "Deadline date"))
          Picker("Category", selection: $category) {
            ForEach(DeadlineCategory.allCases) { option in
              Text(option.displayName).tag(option)
            }
          }
          .accessibilityLabel(String(localized: "Deadline category"))
        }
      }
      .navigationTitle(existingDeadline == nil ? "Add Deadline" : "Edit Deadline")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel).disabled(isSaving)
        }
        ToolbarItem(placement: .confirmationAction) {
          if isSaving {
            ProgressView().accessibilityLabel(String(localized: "Saving deadline"))
          } else {
            Button("Save") {
              Task {
                isSaving = true
                let saved = await onSave(trimmedLabel, date, category)
                isSaving = false
                if !saved {
                  // Failure surfaces via the list view's error alert; leave the
                  // sheet open so the user can retry or adjust input.
                }
              }
            }
            .disabled(isSaveDisabled)
          }
        }
      }
    }
  }
}
