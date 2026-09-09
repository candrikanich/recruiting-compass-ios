import SwiftUI

/// Add/edit deadline form. Editing matches web's `PATCH /api/deadlines/:id`.
/// School association is optional, mirroring Events' picker (nil ⇄ "none"
/// sentinel), not the shared `SchoolPicker` component which is hard-required.
struct AddDeadlineSheet: View {
  let existingDeadline: Deadline?
  let schools: [School]
  let onSave: (String, Date, DeadlineCategory, String?) async -> Bool
  let onCancel: () -> Void

  @State private var label: String
  @State private var date: Date
  @State private var category: DeadlineCategory
  @State private var schoolId: String?
  @State private var isSaving = false

  private static let noSchoolTag = "none"
  private static let maxLabelLength = 200

  init(
    existingDeadline: Deadline? = nil,
    schools: [School] = [],
    onSave: @escaping (String, Date, DeadlineCategory, String?) async -> Bool,
    onCancel: @escaping () -> Void
  ) {
    self.existingDeadline = existingDeadline
    self.schools = schools
    self.onSave = onSave
    self.onCancel = onCancel
    _label = State(initialValue: existingDeadline?.label ?? "")
    _date = State(initialValue: existingDeadline.flatMap { AddDeadlineSheet.parseISODate($0.deadlineDate) } ?? .now)
    _category = State(initialValue: existingDeadline?.category ?? .application)
    _schoolId = State(initialValue: existingDeadline?.schoolId)
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

  private var schoolIdBinding: Binding<String> {
    Binding(
      get: { schoolId ?? Self.noSchoolTag },
      set: { schoolId = $0 == Self.noSchoolTag ? nil : $0 }
    )
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
          Picker("School", selection: schoolIdBinding) {
            Text("None").tag(Self.noSchoolTag)
            ForEach(schools) { school in
              Text(school.name).tag(school.id)
            }
          }
          .accessibilityLabel(String(localized: "Associated school"))
          .accessibilityHint("Optional — link this deadline to a school")
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
                let saved = await onSave(trimmedLabel, date, category, schoolId)
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
