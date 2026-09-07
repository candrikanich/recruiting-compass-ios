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
            TextField("Primary Color (hex)", text: $info.schoolColor1)
              .autocapitalization(.none)
            if !info.schoolColor1.isEmpty {
              Circle()
                .fill(Color(hex: info.schoolColor1))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
          }

          HStack {
            TextField("Secondary Color (hex)", text: $info.schoolColor2)
              .autocapitalization(.none)
            if !info.schoolColor2.isEmpty {
              Circle()
                .fill(Color(hex: info.schoolColor2))
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
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
