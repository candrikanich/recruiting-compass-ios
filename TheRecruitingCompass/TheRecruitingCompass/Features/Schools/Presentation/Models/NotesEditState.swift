import Foundation

/// State for notes editing
struct NotesEditState {
  var isEditing = false
  var content = ""
  var isSaving = false

  mutating func reset() {
    isEditing = false
    content = ""
    isSaving = false
  }
}
