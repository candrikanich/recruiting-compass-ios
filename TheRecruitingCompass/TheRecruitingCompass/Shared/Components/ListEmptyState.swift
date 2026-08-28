import SwiftUI

/// Three-way empty state used by list screens: filtered miss, blocked
/// prerequisite, or genuine empty collection.
struct ListEmptyState: View {
  struct Copy {
    var icon: String
    var title: String
    var message: String
    var actionTitle: String? = nil
    var actionHint: String? = nil
    var action: (() -> Void)? = nil
  }

  let isFilteredEmpty: Bool
  var isBlocked: Bool = false
  let filtered: Copy
  var blocked: Copy? = nil
  let empty: Copy

  var body: some View {
    let copy: Copy = {
      if isFilteredEmpty { return filtered }
      if isBlocked, let blocked { return blocked }
      return empty
    }()

    EmptyStateView(
      icon: copy.icon,
      title: copy.title,
      message: copy.message,
      actionTitle: copy.actionTitle,
      actionHint: copy.actionHint,
      action: copy.action
    )
  }
}
