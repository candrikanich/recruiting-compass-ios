import Foundation

/// State for coaching philosophy editing
struct CoachingPhilosophyEditState {
  var isEditing = false
  var data = EditableCoachingPhilosophy()
  var isSaving = false

  mutating func reset() {
    isEditing = false
    data = EditableCoachingPhilosophy()
    isSaving = false
  }
}
