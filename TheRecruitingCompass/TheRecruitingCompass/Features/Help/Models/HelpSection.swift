//
//  HelpSection.swift
//  TheRecruitingCompass
//
//  Help Center topic sections matching the web app.
//

import SwiftUI

enum HelpSection: String, CaseIterable, Identifiable, Hashable {
  case gettingStarted
  case schools
  case phases
  case account

  var id: String { rawValue }

  var slug: String {
    switch self {
    case .gettingStarted: return "getting-started"
    case .schools: return "schools"
    case .phases: return "phases"
    case .account: return "account"
    }
  }

  /// Initialize from URL path slug (e.g. "getting-started"). Returns nil for unknown slug.
  init?(slug: String) {
    switch slug {
    case "getting-started": self = .gettingStarted
    case "schools": self = .schools
    case "phases": self = .phases
    case "account": self = .account
    default: return nil
    }
  }

  var title: String {
    switch self {
    case .gettingStarted: return "Getting Started"
    case .schools: return "Schools & Coaches"
    case .phases: return "Phases & Letters"
    case .account: return "Account & Settings"
    }
  }

  var description: String {
    switch self {
    case .gettingStarted: return "Set up your profile and learn the basics of the recruiting dashboard."
    case .schools: return "Add schools, understand fit scores, and track coach interactions."
    case .phases: return "Navigate recruiting phases and manage recommendation letter requests."
    case .account: return "Manage your family, notifications, profile, and account preferences."
    }
  }

  var icon: String {
    switch self {
    case .gettingStarted: return "sparkles"
    case .schools: return "building.2"
    case .phases: return "chart.bar"
    case .account: return "gearshape"
    }
  }
}
