import Foundation

/// State for basic info editing
struct BasicInfoEditState {
  var isEditing = false
  var data = EditableBasicInfo()
  var isSaving = false

  mutating func reset() {
    isEditing = false
    data = EditableBasicInfo()
    isSaving = false
  }
}
