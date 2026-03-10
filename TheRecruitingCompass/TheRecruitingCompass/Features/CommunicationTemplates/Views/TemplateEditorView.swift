import SwiftUI

struct TemplateEditorView: View {
  @Bindable var viewModel: CommunicationTemplatesViewModel
  @FocusState private var bodyFieldFocused: Bool

  private var isEditing: Bool { viewModel.editingTemplate != nil }

  private var title: String {
    isEditing ? "Edit Template" : "Create Template"
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        nameField
        typePicker
        bodyEditor
        variablesGuide
        actionButtons
      }
      .padding()
    }
    .accessibilityIdentifier("templateEditorView")
  }

  private var nameField: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Template Name")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)

      TextField("e.g. Initial Contact Email", text: $viewModel.formData.name)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Template name")
        .accessibilityIdentifier("templateEditor.nameField")
    }
  }

  private var typePicker: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Template Type")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)

      Picker("Type", selection: $viewModel.formData.type) {
        ForEach(TemplateType.allCases, id: \.self) { type in
          Text(type.displayName).tag(type)
        }
      }
      .pickerStyle(.segmented)
      .accessibilityLabel("Template Type")
      .accessibilityIdentifier("templateEditor.typePicker")
    }
  }

  private var bodyEditor: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Body")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)

      TextEditor(text: $viewModel.formData.body)
        .frame(minHeight: 200)
        .padding(4)
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(.systemGray4), lineWidth: 1)
        }
        .focused($bodyFieldFocused)
        .accessibilityLabel("Template body")
        .accessibilityIdentifier("templateEditor.bodyEditor")
    }
  }

  private var variablesGuide: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Available Variables")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)

      Text("Tap a variable to insert it into the body.")
        .font(.caption)
        .foregroundStyle(.secondary)

      FlowLayout(spacing: 8) {
        ForEach(TemplateVariable.all, id: \.key) { variable in
          Button {
            viewModel.formData.body.append("{{" + variable.key + "}}")
            bodyFieldFocused = true
          } label: {
            Text("{{" + variable.key + "}}")
              .font(.caption.monospaced())
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Color.accentBlue.opacity(0.1))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Insert \(variable.name) variable")
        }
      }
    }
    .padding()
    .background(Color(.tertiarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button {
        Task { await viewModel.saveTemplate() }
      } label: {
        Text(isEditing ? "Save Changes" : "Save Template")
          .font(.body.weight(.semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(viewModel.formData.isValid ? Color.accentBlue : Color.gray)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .disabled(!viewModel.formData.isValid)
      .accessibilityLabel(isEditing ? "Save Changes" : "Save Template")
      .accessibilityIdentifier("templateEditor.saveButton")

      Button {
        viewModel.cancelEdit()
      } label: {
        Text("Cancel")
          .font(.body)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .accessibilityLabel("Cancel")
      .accessibilityIdentifier("templateEditor.cancelButton")

      if isEditing, let editingTemplate = viewModel.editingTemplate {
        Button(role: .destructive) {
          viewModel.confirmDelete(id: editingTemplate.id)
        } label: {
          Text("Delete Template")
            .font(.body.weight(.medium))
            .foregroundStyle(Color.errorRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .accessibilityLabel("Delete Template")
        .accessibilityIdentifier("templateEditor.deleteButton")
      }
    }
  }
}
