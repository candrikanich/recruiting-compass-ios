import SwiftUI

struct SchoolBasicInfoSheet: View {
  @Binding var info: EditableBasicInfo
  let onSave: () async -> Void
  let onCancel: () -> Void
  let isSaving: Bool

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("Location") {
          TextField("Campus Address", text: $info.address)
            .textContentType(.fullStreetAddress)

          TextField("Baseball Facility Address", text: $info.baseballFacilityAddress)
            .textContentType(.fullStreetAddress)
        }

        Section("School Details") {
          TextField("Mascot", text: $info.mascot)

          TextField("Undergrad Size", text: $info.undergradSize)
            .keyboardType(.numberPad)
        }

        Section("Online Presence") {
          TextField("Website", text: $info.website)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)

          TextField("Twitter Handle", text: $info.twitterHandle)
            .autocapitalization(.none)

          TextField("Instagram Handle", text: $info.instagramHandle)
            .autocapitalization(.none)
        }
      }
      .navigationTitle("Edit Information")
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
      baseballFacilityAddress: "456 Stadium Dr",
      mascot: "Longhorns",
      undergradSize: "40000",
      website: "utexas.edu",
      twitterHandle: "@TexasBaseball",
      instagramHandle: "@texasbaseball"
    )),
    onSave: {},
    onCancel: {},
    isSaving: false
  )
}
