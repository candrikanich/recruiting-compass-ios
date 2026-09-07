import SwiftUI

struct SchoolBasicInfoSheet: View {
  @Binding var info: EditableBasicInfo
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isSaving: Bool

  @Environment(\.dismiss) private var dismiss

  @ViewBuilder
  private func colorSwatch(hex: String) -> some View {
    Circle()
      .fill(hex.isEmpty ? Color(.systemGray4) : Color(hex: hex))
      .frame(width: 24, height: 24)
      .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 1))
      .accessibilityHidden(true)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Contact & Social") {
          TextField("Campus Address", text: $info.address)
            .textContentType(.fullStreetAddress)

          TextField("Phone", text: $info.phone)
            .textContentType(.telephoneNumber)
            .keyboardType(.phonePad)

          TextField("Website", text: $info.website)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)

          TextField("Athletics Website", text: $info.athleticsUrl)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)

          TextField("Mascot", text: $info.mascot)

          HStack {
            colorSwatch(hex: info.schoolColorPrimary)
            TextField("#660000", text: $info.schoolColorPrimary)
              .autocapitalization(.none)
              .disableAutocorrection(true)
          }

          HStack {
            colorSwatch(hex: info.schoolColorSecondary)
            TextField("#FFFFFF", text: $info.schoolColorSecondary)
              .autocapitalization(.none)
              .disableAutocorrection(true)
          }

          TextField("Twitter Handle", text: $info.twitterHandle)
            .autocapitalization(.none)

          TextField("Instagram Handle", text: $info.instagramHandle)
            .autocapitalization(.none)
        }
      }
      .navigationTitle("Edit Contact & Social")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            onCancel()
            dismiss()
          }
          .disabled(isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              await onSave()
              dismiss()
            }
          } label: {
            if isSaving {
              ProgressView()
                .progressViewStyle(.circular)
            } else {
              Text("Save")
            }
          }
          .disabled(isSaving)
        }
      }
    }
  }
}

#Preview {
  SchoolBasicInfoSheet(
    info: .constant(EditableBasicInfo(
      address: "123 University Ave",
      phone: "(512) 471-3333",
      website: "utexas.edu",
      athleticsUrl: "texassports.com",
      twitterHandle: "@TexasBaseball",
      instagramHandle: "@texasbaseball"
    )),
    onSave: {},
    onCancel: {},
    isSaving: false
  )
}
