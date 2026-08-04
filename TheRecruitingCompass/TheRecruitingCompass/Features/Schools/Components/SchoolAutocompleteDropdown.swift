//
//  SchoolAutocompleteDropdown.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 2: Autocomplete dropdown for college search
//

import SwiftUI

struct SchoolAutocompleteDropdown: View {
  let results: [CollegeSearchResult]
  let isLoading: Bool
  let error: String?
  let onSelect: (CollegeSearchResult) -> Void

  var body: some View {
    VStack(spacing: 0) {
      if isLoading {
        loadingView
      } else if let error {
        errorView(error)
      } else if results.isEmpty {
        emptyView
      } else {
        resultsList
      }
    }
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 8))
    .brandShadowSm()
    .onChange(of: results) { _, newValue in
      guard !isLoading else { return }
      let message = newValue.isEmpty
        ? "No colleges found"
        : "\(newValue.count) college\(newValue.count == 1 ? "" : "s") found"
      AccessibilityNotification.Announcement(message).post()
    }
  }

  // MARK: - Loading View

  @ViewBuilder
  private var loadingView: some View {
    HStack {
      ProgressView()
        .progressViewStyle(.circular)
        .accessibilityLabel("Searching colleges")

      Text("Searching...")
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Error View

  private func errorView(_ message: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .accessibilityHidden(true)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(message)
  }

  // MARK: - Empty View

  @ViewBuilder
  private var emptyView: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No colleges found. Try a different search or switch to manual entry.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No colleges found")
  }

  // MARK: - Results List

  @ViewBuilder
  private var resultsList: some View {
    VStack(spacing: 0) {
      ForEach(results) { college in
        Button {
          onSelect(college)
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(college.name)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

              Text(college.location)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
          .padding(.vertical, 16)
          .padding(.horizontal, 16)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(college.name), \(college.location)")
        .accessibilityHint("Select this college to auto-fill form")
        .accessibilityAddTraits(.isButton)

        if college.id != results.last?.id {
          Divider()
            .padding(.leading, 16)
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(results.count) college\(results.count == 1 ? "" : "s") found")
  }
}

// MARK: - Preview

#Preview("Loading", traits: .sizeThatFitsLayout) {
  SchoolAutocompleteDropdown(
    results: [],
    isLoading: true,
    error: nil,
    onSelect: { _ in }
  )
  .padding()
}

#Preview("Results", traits: .sizeThatFitsLayout) {
  SchoolAutocompleteDropdown(
    results: [
      CollegeSearchResult(id: "1", name: "University of Florida", city: "Gainesville", state: "FL", website: "https://ufl.edu"),
      CollegeSearchResult(id: "2", name: "Florida State University", city: "Tallahassee", state: "FL", website: "https://fsu.edu"),
      CollegeSearchResult(id: "3", name: "University of Central Florida", city: "Orlando", state: "FL", website: "https://ucf.edu")
    ],
    isLoading: false,
    error: nil,
    onSelect: { _ in }
  )
  .padding()
}

#Preview("Error", traits: .sizeThatFitsLayout) {
  SchoolAutocompleteDropdown(
    results: [],
    isLoading: false,
    error: "College search is not configured. Please enter the school manually.",
    onSelect: { _ in }
  )
  .padding()
}

#Preview("Empty", traits: .sizeThatFitsLayout) {
  SchoolAutocompleteDropdown(
    results: [],
    isLoading: false,
    error: nil,
    onSelect: { _ in }
  )
  .padding()
}
