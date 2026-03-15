import SwiftUI

/// Protocol for announcing messages to VoiceOver users
protocol AccessibilityAnnouncing {
  func announce(_ message: String)
}

/// Default implementation using SwiftUI's AccessibilityNotification
final class AccessibilityAnnouncer: AccessibilityAnnouncing {
  func announce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
  }
}

/// Mock implementation for testing
final class MockAccessibilityAnnouncer: AccessibilityAnnouncing {
  var announcedMessages: [String] = []

  func announce(_ message: String) {
    announcedMessages.append(message)
  }

  func reset() {
    announcedMessages.removeAll()
  }
}
