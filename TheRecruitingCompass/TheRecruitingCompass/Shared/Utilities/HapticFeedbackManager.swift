import UIKit

/// Manages haptic feedback for user interactions
final class HapticFeedbackManager {
  static let shared = HapticFeedbackManager()

  private init() {}

  /// Success feedback (e.g., form submitted, action completed)
  func success() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
  }

  /// Error feedback (e.g., validation failed, operation failed)
  func error() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.error)
  }

  /// Warning feedback (e.g., delete confirmation, destructive action)
  func warning() {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.warning)
  }

  /// Light impact feedback (e.g., selection change, toggle)
  func lightImpact() {
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }

  /// Medium impact feedback (e.g., button press, action)
  func mediumImpact() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
  }

  /// Heavy impact feedback (e.g., delete, major action)
  func heavyImpact() {
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    generator.impactOccurred()
  }

  /// Selection feedback (e.g., picker change, segment control)
  func selectionChanged() {
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
  }
}
