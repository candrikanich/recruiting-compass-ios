import SwiftUI

/// Add-deadline form. School association and edit are deferred (spec §9,
/// matches web — no edit endpoint either).
struct AddDeadlineSheet: View {
  let onSave: (String, Date, DeadlineCategory) async -> Bool
  let onCancel: () -> Void

  @State private var label = ""
  @State private var date = Date.now
  @State private var category: DeadlineCategory = .application
  @State private var isSaving = false

  private static let maxLabelLength = 200

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
      .navigationTitle("Add Deadline")
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
