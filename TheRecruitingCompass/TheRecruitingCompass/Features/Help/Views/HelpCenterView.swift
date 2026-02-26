//
//  HelpCenterView.swift
//  TheRecruitingCompass
//
//  Help Center overview: title + grid of section cards (matches web /help).
//

import SwiftUI

struct HelpCenterView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        headerView

        LazyVGrid(columns: [
          GridItem(.flexible(), spacing: 16),
          GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
          ForEach(HelpSection.allCases) { section in
            NavigationLink(value: MorePath.helpSection(slug: section.slug)) {
              HelpOverviewCard(section: section)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.title)
            .accessibilityHint("Opens \(section.title) help")
          }
        }
      }
      .padding()
    }
    .navigationTitle("Help Center")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var headerView: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Help Center")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(.primary)

      Text("Everything you need to use The Recruiting Compass.")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Help Center. Everything you need to use The Recruiting Compass.")
  }
}

// MARK: - Overview Card
private struct HelpOverviewCard: View {
  let section: HelpSection

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: section.icon)
        .font(.title2)
        .foregroundStyle(Color.accentBlue)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(section.title)
          .font(.body)
          .fontWeight(.semibold)
          .foregroundColor(.primary)

        Text(section.description)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(3)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(section.title): \(section.description)")
  }
}

#Preview {
  NavigationStack {
    HelpCenterView()
  }
}
