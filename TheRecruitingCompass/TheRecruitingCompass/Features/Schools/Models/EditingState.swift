import Foundation

/// Groups all editing-related state for SchoolDetailViewModel
struct EditingState {
  var notes = NotesEditState()
  var privateNotes = NotesEditState()
  var basicInfo = BasicInfoEditState()
  var coachingPhilosophy = CoachingPhilosophyEditState()
}

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
