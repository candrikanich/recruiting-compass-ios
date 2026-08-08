import SwiftUI

struct AddEditVideoLinkView: View {
  private let viewModel: VideoLinksEditorViewModel
  private let editingLink: VideoLink?

  @State private var platform: VideoLinkPlatform
  @State private var url: String
  @State private var title: String
  @Environment(\.dismiss) private var dismiss

  init(viewModel: VideoLinksEditorViewModel, editingLink: VideoLink?) {
    self.viewModel = viewModel
    self.editingLink = editingLink
    _platform = State(initialValue: editingLink?.platform ?? .hudl)
    _url = State(initialValue: editingLink?.url ?? "")
    _title = State(initialValue: editingLink?.title ?? "")
  }

  private var isValidURL: Bool {
    guard let parsed = URL(string: url), parsed.scheme != nil else { return false }
    return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    Form {
      Section {
        Picker("Platform", selection: $platform) {
          ForEach(VideoLinkPlatform.selectable, id: \.self) { platform in
            Text(platform.displayName).tag(platform)
          }
        }
        .accessibilityLabel(String(localized: "Platform picker"))

        TextField("URL", text: $url)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .accessibilityLabel(String(localized: "Video URL field"))
          .accessibilityHint("Required. Paste the link to your film")

        TextField("Title (optional)", text: $title)
          .accessibilityLabel(String(localized: "Title field"))
          .accessibilityHint("Optional. A short label for this link")
      }
    }
    .navigationTitle(editingLink == nil ? String(localized: "Add Video Link") : String(localized: "Edit Video Link"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
          dismiss()
        }
        .disabled(viewModel.isSubmitting)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task {
            let success = await save()
            if success { dismiss() }
          }
        } label: {
          if viewModel.isSubmitting {
            ProgressView()
          } else {
            Text("Save")
          }
        }
        .disabled(!isValidURL || viewModel.isSubmitting)
      }
    }
  }

  private func save() async -> Bool {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if let editingLink {
      return await viewModel.updateLink(
        id: editingLink.id, platform: platform, url: url,
        title: trimmedTitle.isEmpty ? nil : trimmedTitle)
    } else {
      return await viewModel.addLink(
        platform: platform, url: url,
        title: trimmedTitle.isEmpty ? nil : trimmedTitle)
    }
  }
}
