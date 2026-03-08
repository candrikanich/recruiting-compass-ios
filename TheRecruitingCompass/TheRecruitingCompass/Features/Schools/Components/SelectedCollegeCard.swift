//
//  SelectedCollegeCard.swift
//  TheRecruitingCompass
//
//  Created on 2026-02-11
//  Phase 2: Selected college confirmation card
//

import SwiftUI

struct SelectedCollegeCard: View {
  let college: CollegeSearchResult
  let isEnrichmentLoading: Bool
  let onClear: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      // Checkmark icon
      Image(systemName: "checkmark.circle.fill")
        .font(.title2)
        .foregroundStyle(.green)
        .accessibilityHidden(true)

      // College info
      VStack(alignment: .leading, spacing: 4) {
        Text("Selected: \(college.name)")
          .font(.headline)
          .foregroundStyle(.primary)

        Text(college.location)
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if isEnrichmentLoading {
          HStack(spacing: 8) {
            ProgressView()
              .progressViewStyle(.circular)
              .scaleEffect(0.8)
              .accessibilityLabel("Loading college data")

            Text("Fetching college data...")
              .font(.caption)
              .foregroundStyle(.blue)
          }
        } else {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
              .accessibilityHidden(true)

            Text("College data and map coordinates loaded")
              .font(.caption)
              .foregroundStyle(.green)
          }
        }
      }

      Spacer()

      // Clear button
      Button {
        onClear()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.title3)
          .foregroundStyle(.gray)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Clear selection")
      .accessibilityHint("Remove selected college and clear auto-filled fields")
    }
    .padding()
    .background(Color.green.opacity(0.1))
    .clipShape(.rect(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.green, lineWidth: 1)
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Selected college: \(college.name), \(college.location)")
  }
}

// MARK: - Preview

#Preview("Loading", traits: .sizeThatFitsLayout) {
  SelectedCollegeCard(
    college: CollegeSearchResult(
      id: "1",
      name: "University of Florida",
      city: "Gainesville",
      state: "FL",
      website: "https://ufl.edu"
    ),
    isEnrichmentLoading: true,
    onClear: { }
  )
  .padding()
}

#Preview("Loaded", traits: .sizeThatFitsLayout) {
  SelectedCollegeCard(
    college: CollegeSearchResult(
      id: "1",
      name: "University of Florida",
      city: "Gainesville",
      state: "FL",
      website: "https://ufl.edu"
    ),
    isEnrichmentLoading: false,
    onClear: { }
  )
  .padding()
}
