//
//  AccessibilityAnnouncing.swift
//  TheRecruitingCompass
//
//  Protocol for announcing messages to VoiceOver users
//

import Foundation
import UIKit

/// Protocol for announcing accessibility messages and providing haptic feedback
protocol AccessibilityAnnouncing {
  /// Announces a message to VoiceOver users
  /// - Parameter message: The message to announce
  func announce(_ message: String)

  /// Announces a message with haptic feedback
  /// - Parameters:
  ///   - message: The message to announce
  ///   - success: Whether the operation was successful (determines haptic type)
  func announceWithFeedback(_ message: String, success: Bool)
}

/// Default implementation using UIKit's UIAccessibility
final class UIAccessibilityAnnouncer: AccessibilityAnnouncing {

  func announce(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
  }

  func announceWithFeedback(_ message: String, success: Bool) {
    // Provide haptic feedback
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(success ? .success : .error)

    // Announce message
    UIAccessibility.post(notification: .announcement, argument: message)
  }
}

/// Mock implementation for testing
final class MockAccessibilityAnnouncer: AccessibilityAnnouncing {
  var announcedMessages: [String] = []
  var lastFeedbackType: Bool?

  func announce(_ message: String) {
    announcedMessages.append(message)
  }

  func announceWithFeedback(_ message: String, success: Bool) {
    announcedMessages.append(message)
    lastFeedbackType = success
  }

  func reset() {
    announcedMessages.removeAll()
    lastFeedbackType = nil
  }
}
