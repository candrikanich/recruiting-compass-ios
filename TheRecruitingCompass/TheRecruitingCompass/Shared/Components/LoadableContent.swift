import SwiftUI

/// Switches loading / empty / failed / populated without each screen rewriting
/// the same if/else. Errors with existing data stay `.populated` — show a banner
/// above this view instead of replacing the list.
struct LoadableContent<Content: View, Empty: View, Failure: View>: View {
  let phase: LoadablePhase
  var loadingMessage: String = "Loading..."
  @ViewBuilder var empty: () -> Empty
  @ViewBuilder var failure: () -> Failure
  @ViewBuilder var content: () -> Content

  var body: some View {
    switch phase {
    case .loading:
      LoadingStateView(message: loadingMessage)
    case .empty:
      empty()
    case .failed:
      failure()
    case .populated:
      content()
    }
  }
}

extension LoadableContent where Failure == InlineErrorView {
  init(
    isLoading: Bool,
    isEmpty: Bool,
    errorMessage: String? = nil,
    loadingMessage: String = "Loading...",
    onRetry: (() -> Void)? = nil,
    @ViewBuilder empty: @escaping () -> Empty,
    @ViewBuilder content: @escaping () -> Content
  ) {
    let phase = LoadablePhase.resolve(
      isLoading: isLoading,
      isEmpty: isEmpty,
      errorMessage: errorMessage
    )
    self.init(
      phase: phase,
      loadingMessage: loadingMessage,
      empty: empty,
      failure: {
        InlineErrorView(
          message: errorMessage ?? String(localized: "Something went wrong"),
          onRetry: onRetry
        )
      },
      content: content
    )
  }
}

#Preview("Loading") {
  LoadableContent(isLoading: true, isEmpty: true, loadingMessage: "Loading schools...") {
    EmptyStateView(icon: "building.columns", title: "No Schools Yet", message: "Add a school to start tracking.")
  } content: {
    Text("List")
  }
}

#Preview("Empty") {
  LoadableContent(isLoading: false, isEmpty: true) {
    EmptyStateView(
      icon: "building.columns",
      title: "No Schools Yet",
      message: "Add a school to start tracking.",
      actionTitle: "Add School",
      action: {}
    )
  } content: {
    Text("List")
  }
}

#Preview("Failed") {
  LoadableContent(
    isLoading: false,
    isEmpty: true,
    errorMessage: "Unable to load schools.",
    onRetry: {}
  ) {
    EmptyStateView(icon: "building.columns", title: "No Schools Yet", message: "Add a school to start tracking.")
  } content: {
    Text("List")
  }
}

#Preview("Populated") {
  LoadableContent(isLoading: false, isEmpty: false) {
    EmptyStateView(icon: "building.columns", title: "No Schools Yet", message: "Add a school to start tracking.")
  } content: {
    Text("Ohio State")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
