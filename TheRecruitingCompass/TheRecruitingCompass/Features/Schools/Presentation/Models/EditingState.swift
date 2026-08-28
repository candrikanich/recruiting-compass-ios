import Foundation

/// Groups all editing-related state for SchoolDetailViewModel
struct EditingState {
  var notes = NotesEditState()
  var basicInfo = BasicInfoEditState()
  var coachingPhilosophy = CoachingPhilosophyEditState()
}
